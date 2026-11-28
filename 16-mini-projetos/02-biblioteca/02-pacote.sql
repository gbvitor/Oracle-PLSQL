-- =============================================================================
-- Projeto : 02 — Biblioteca — package BIB_PKG_BIBLIOTECA
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : 01-tabelas.sql; CREATE PROCEDURE
--
-- Empréstimo, devolução com multa, renovação, reserva com fila e expiração.
-- Todas as datas são parâmetros (padrão: hoje), para os testes não dependerem
-- do dia em que rodam. Sem COMMIT: quem chama decide a transação.
-- =============================================================================

CREATE OR REPLACE PACKAGE bib_pkg_biblioteca AS

    c_dias_retirada CONSTANT PLS_INTEGER := 2;  -- prazo para retirar a reserva separada

    e_leitor_invalido        EXCEPTION;  PRAGMA EXCEPTION_INIT(e_leitor_invalido,        -20201);
    e_limite_emprestimos     EXCEPTION;  PRAGMA EXCEPTION_INIT(e_limite_emprestimos,     -20202);
    e_multa_pendente         EXCEPTION;  PRAGMA EXCEPTION_INIT(e_multa_pendente,         -20203);
    e_emprestimo_em_atraso   EXCEPTION;  PRAGMA EXCEPTION_INIT(e_emprestimo_em_atraso,   -20204);
    e_exemplar_indisponivel  EXCEPTION;  PRAGMA EXCEPTION_INIT(e_exemplar_indisponivel,  -20205);
    e_renovacao_em_atraso    EXCEPTION;  PRAGMA EXCEPTION_INIT(e_renovacao_em_atraso,    -20206);
    e_limite_renovacoes      EXCEPTION;  PRAGMA EXCEPTION_INIT(e_limite_renovacoes,      -20207);
    e_obra_com_fila          EXCEPTION;  PRAGMA EXCEPTION_INIT(e_obra_com_fila,          -20208);
    e_obra_disponivel        EXCEPTION;  PRAGMA EXCEPTION_INIT(e_obra_disponivel,        -20209);
    e_reserva_duplicada      EXCEPTION;  PRAGMA EXCEPTION_INIT(e_reserva_duplicada,      -20210);
    e_nao_emprestado         EXCEPTION;  PRAGMA EXCEPTION_INIT(e_nao_emprestado,         -20211);
    e_obra_inexistente       EXCEPTION;  PRAGMA EXCEPTION_INIT(e_obra_inexistente,       -20212);
    e_reserva_fechada        EXCEPTION;  PRAGMA EXCEPTION_INIT(e_reserva_fechada,        -20213);

    FUNCTION emprestar (
        p_id_leitor   IN bib_leitores.id_leitor%TYPE,
        p_id_exemplar IN bib_exemplares.id_exemplar%TYPE,
        p_data        IN DATE DEFAULT TRUNC(SYSDATE)
    ) RETURN bib_emprestimos.id_emprestimo%TYPE;

    -- Devolve o valor da multa gerada (0 se no prazo).
    FUNCTION devolver (
        p_id_exemplar IN bib_exemplares.id_exemplar%TYPE,
        p_data        IN DATE DEFAULT TRUNC(SYSDATE)
    ) RETURN NUMBER;

    PROCEDURE renovar (
        p_id_emprestimo IN bib_emprestimos.id_emprestimo%TYPE,
        p_data          IN DATE DEFAULT TRUNC(SYSDATE)
    );

    FUNCTION reservar (
        p_id_leitor IN bib_leitores.id_leitor%TYPE,
        p_id_obra   IN bib_obras.id_obra%TYPE,
        p_data      IN DATE DEFAULT SYSDATE
    ) RETURN bib_reservas.id_reserva%TYPE;

    PROCEDURE cancelar_reserva (
        p_id_reserva IN bib_reservas.id_reserva%TYPE,
        p_data       IN DATE DEFAULT TRUNC(SYSDATE)
    );

    -- Expira as reservas separadas e não retiradas no prazo; passa o exemplar para
    -- o próximo da fila. Devolve quantas expiraram. Candidata a job diário.
    FUNCTION expirar_reservas (p_data IN DATE DEFAULT TRUNC(SYSDATE)) RETURN PLS_INTEGER;

    -- Marca como pagas as multas do leitor. Devolve o total pago.
    FUNCTION pagar_multas (p_id_leitor IN bib_leitores.id_leitor%TYPE) RETURN NUMBER;

    FUNCTION multa_pendente (p_id_leitor IN bib_leitores.id_leitor%TYPE) RETURN NUMBER;

END bib_pkg_biblioteca;
/

CREATE OR REPLACE PACKAGE BODY bib_pkg_biblioteca AS

    -- Regras da categoria do leitor; trava a linha do leitor para que duas
    -- sessões não emprestem ao mesmo tempo e passem juntas do limite.
    FUNCTION travar_leitor (p_id_leitor IN bib_leitores.id_leitor%TYPE)
        RETURN bib_categorias_leitor%ROWTYPE
    IS
        v_ativo  bib_leitores.ativo%TYPE;
        v_regras bib_categorias_leitor%ROWTYPE;
    BEGIN
        SELECT l.ativo INTO v_ativo
          FROM bib_leitores l
         WHERE l.id_leitor = p_id_leitor
           FOR UPDATE;

        IF v_ativo <> 'S' THEN
            RAISE_APPLICATION_ERROR(-20201, 'Leitor inativo: ' || p_id_leitor);
        END IF;

        SELECT c.* INTO v_regras
          FROM bib_categorias_leitor c
          JOIN bib_leitores l ON l.categoria = c.categoria
         WHERE l.id_leitor = p_id_leitor;

        RETURN v_regras;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20201, 'Leitor inexistente: ' || NVL(TO_CHAR(p_id_leitor), 'nulo'));
    END travar_leitor;

    FUNCTION multa_pendente (p_id_leitor IN bib_leitores.id_leitor%TYPE) RETURN NUMBER IS
        v_total NUMBER;
    BEGIN
        SELECT NVL(SUM(valor_multa), 0)
          INTO v_total
          FROM bib_emprestimos
         WHERE id_leitor = p_id_leitor
           AND valor_multa > 0
           AND multa_paga = 'N';
        RETURN v_total;
    END multa_pendente;

    -- Exemplar que voltou (ou reserva que caiu): vai para o primeiro da fila da
    -- obra ou fica disponível.
    PROCEDURE liberar_exemplar (
        p_id_exemplar IN bib_exemplares.id_exemplar%TYPE,
        p_data        IN DATE
    ) IS
        CURSOR c_fila (p_id_obra NUMBER) IS
            SELECT id_reserva
              FROM bib_reservas
             WHERE id_obra = p_id_obra
               AND situacao = 'ATIVA'
             ORDER BY data_reserva, id_reserva
               FOR UPDATE;
        v_id_obra    bib_exemplares.id_obra%TYPE;
        v_id_reserva bib_reservas.id_reserva%TYPE;
    BEGIN
        SELECT id_obra INTO v_id_obra FROM bib_exemplares WHERE id_exemplar = p_id_exemplar;

        OPEN c_fila(v_id_obra);
        FETCH c_fila INTO v_id_reserva;

        IF c_fila%FOUND THEN
            UPDATE bib_reservas
               SET situacao       = 'DISPONIVEL',
                   id_exemplar    = p_id_exemplar,
                   prazo_retirada = TRUNC(p_data) + c_dias_retirada
             WHERE CURRENT OF c_fila;
            UPDATE bib_exemplares SET situacao = 'RESERVADO' WHERE id_exemplar = p_id_exemplar;
        ELSE
            UPDATE bib_exemplares SET situacao = 'DISPONIVEL' WHERE id_exemplar = p_id_exemplar;
        END IF;

        CLOSE c_fila;
    END liberar_exemplar;

    -- -------------------------------------------------------------------------
    FUNCTION emprestar (
        p_id_leitor   IN bib_leitores.id_leitor%TYPE,
        p_id_exemplar IN bib_exemplares.id_exemplar%TYPE,
        p_data        IN DATE DEFAULT TRUNC(SYSDATE)
    ) RETURN bib_emprestimos.id_emprestimo%TYPE IS
        v_regras     bib_categorias_leitor%ROWTYPE;
        v_abertos    PLS_INTEGER;
        v_atrasados  PLS_INTEGER;
        v_situacao   bib_exemplares.situacao%TYPE;
        v_id_reserva bib_reservas.id_reserva%TYPE;
        v_id         bib_emprestimos.id_emprestimo%TYPE;
    BEGIN
        SAVEPOINT sp_bib_emprestar;

        -- Ordem das regras: leitor, multa, atraso, limite, exemplar.
        v_regras := travar_leitor(p_id_leitor);

        IF multa_pendente(p_id_leitor) > 0 THEN
            RAISE_APPLICATION_ERROR(-20203,
                'Leitor ' || p_id_leitor || ' com multa pendente de ' || TO_CHAR(multa_pendente(p_id_leitor)));
        END IF;

        SELECT COUNT(*),
               COUNT(CASE WHEN data_prevista < TRUNC(p_data) THEN 1 END)
          INTO v_abertos, v_atrasados
          FROM bib_emprestimos
         WHERE id_leitor = p_id_leitor
           AND data_devolucao IS NULL;

        IF v_atrasados > 0 THEN
            RAISE_APPLICATION_ERROR(-20204, 'Leitor ' || p_id_leitor || ' com empréstimo em atraso');
        END IF;

        IF v_abertos >= v_regras.max_emprestimos THEN
            RAISE_APPLICATION_ERROR(-20202,
                'Leitor ' || p_id_leitor || ' já tem ' || v_abertos || ' empréstimo(s), limite '
                || v_regras.max_emprestimos);
        END IF;

        BEGIN
            SELECT situacao INTO v_situacao
              FROM bib_exemplares
             WHERE id_exemplar = p_id_exemplar
               FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20205, 'Exemplar inexistente: ' || NVL(TO_CHAR(p_id_exemplar), 'nulo'));
        END;

        IF v_situacao = 'RESERVADO' THEN
            -- Só quem tem a reserva separada pode levar.
            BEGIN
                SELECT id_reserva INTO v_id_reserva
                  FROM bib_reservas
                 WHERE id_exemplar = p_id_exemplar
                   AND situacao = 'DISPONIVEL'
                   AND id_leitor = p_id_leitor
                   FOR UPDATE;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RAISE_APPLICATION_ERROR(-20205,
                        'Exemplar ' || p_id_exemplar || ' reservado para outro leitor');
            END;
            UPDATE bib_reservas SET situacao = 'ATENDIDA' WHERE id_reserva = v_id_reserva;
        ELSIF v_situacao <> 'DISPONIVEL' THEN
            RAISE_APPLICATION_ERROR(-20205,
                'Exemplar ' || p_id_exemplar || ' indisponível (' || v_situacao || ')');
        END IF;

        INSERT INTO bib_emprestimos (id_exemplar, id_leitor, data_emprestimo, data_prevista)
        VALUES (p_id_exemplar, p_id_leitor, TRUNC(p_data), TRUNC(p_data) + v_regras.dias_prazo)
        RETURNING id_emprestimo INTO v_id;

        UPDATE bib_exemplares SET situacao = 'EMPRESTADO' WHERE id_exemplar = p_id_exemplar;

        RETURN v_id;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sp_bib_emprestar;
            RAISE;
    END emprestar;

    -- -------------------------------------------------------------------------
    FUNCTION devolver (
        p_id_exemplar IN bib_exemplares.id_exemplar%TYPE,
        p_data        IN DATE DEFAULT TRUNC(SYSDATE)
    ) RETURN NUMBER IS
        v_id_emprestimo bib_emprestimos.id_emprestimo%TYPE;
        v_prevista      DATE;
        v_multa_dia     bib_categorias_leitor.multa_dia%TYPE;
        v_multa         NUMBER;
    BEGIN
        SAVEPOINT sp_bib_devolver;

        BEGIN
            SELECT e.id_emprestimo, e.data_prevista, c.multa_dia
              INTO v_id_emprestimo, v_prevista, v_multa_dia
              FROM bib_emprestimos e
              JOIN bib_leitores l          ON l.id_leitor = e.id_leitor
              JOIN bib_categorias_leitor c ON c.categoria = l.categoria
             WHERE e.id_exemplar = p_id_exemplar
               AND e.data_devolucao IS NULL
               FOR UPDATE OF e.data_devolucao;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20211, 'Exemplar ' || p_id_exemplar || ' não está emprestado');
        END;

        v_multa := GREATEST(TRUNC(p_data) - v_prevista, 0) * v_multa_dia;

        UPDATE bib_emprestimos
           SET data_devolucao = TRUNC(p_data),
               valor_multa    = v_multa
         WHERE id_emprestimo = v_id_emprestimo;

        liberar_exemplar(p_id_exemplar, p_data);

        RETURN v_multa;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sp_bib_devolver;
            RAISE;
    END devolver;

    -- -------------------------------------------------------------------------
    PROCEDURE renovar (
        p_id_emprestimo IN bib_emprestimos.id_emprestimo%TYPE,
        p_data          IN DATE DEFAULT TRUNC(SYSDATE)
    ) IS
        v_prevista   DATE;
        v_renovacoes bib_emprestimos.renovacoes%TYPE;
        v_id_obra    bib_obras.id_obra%TYPE;
        v_regras     bib_categorias_leitor%ROWTYPE;
        v_fila       PLS_INTEGER;
    BEGIN
        BEGIN
            SELECT e.data_prevista, e.renovacoes, x.id_obra, c.max_renovacoes, c.dias_prazo
              INTO v_prevista, v_renovacoes, v_id_obra, v_regras.max_renovacoes, v_regras.dias_prazo
              FROM bib_emprestimos e
              JOIN bib_exemplares x        ON x.id_exemplar = e.id_exemplar
              JOIN bib_leitores l          ON l.id_leitor = e.id_leitor
              JOIN bib_categorias_leitor c ON c.categoria = l.categoria
             WHERE e.id_emprestimo = p_id_emprestimo
               AND e.data_devolucao IS NULL
               FOR UPDATE OF e.data_prevista;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20211, 'Empréstimo ' || p_id_emprestimo || ' não está aberto');
        END;

        IF TRUNC(p_data) > v_prevista THEN
            RAISE_APPLICATION_ERROR(-20206, 'Empréstimo em atraso não pode ser renovado');
        END IF;

        IF v_renovacoes >= v_regras.max_renovacoes THEN
            RAISE_APPLICATION_ERROR(-20207, 'Limite de ' || v_regras.max_renovacoes || ' renovação(ões) atingido');
        END IF;

        SELECT COUNT(*) INTO v_fila
          FROM bib_reservas
         WHERE id_obra = v_id_obra
           AND situacao = 'ATIVA';

        IF v_fila > 0 THEN
            RAISE_APPLICATION_ERROR(-20208, 'Obra com ' || v_fila || ' reserva(s) na fila');
        END IF;

        UPDATE bib_emprestimos
           SET data_prevista = TRUNC(p_data) + v_regras.dias_prazo,
               renovacoes    = renovacoes + 1
         WHERE id_emprestimo = p_id_emprestimo;
    END renovar;

    -- -------------------------------------------------------------------------
    FUNCTION reservar (
        p_id_leitor IN bib_leitores.id_leitor%TYPE,
        p_id_obra   IN bib_obras.id_obra%TYPE,
        p_data      IN DATE DEFAULT SYSDATE
    ) RETURN bib_reservas.id_reserva%TYPE IS
        v_regras      bib_categorias_leitor%ROWTYPE;
        v_existe      PLS_INTEGER;
        v_disponiveis PLS_INTEGER;
        v_id          bib_reservas.id_reserva%TYPE;
    BEGIN
        v_regras := travar_leitor(p_id_leitor);

        BEGIN
            SELECT 1 INTO v_existe FROM bib_obras WHERE id_obra = p_id_obra;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20212, 'Obra inexistente: ' || NVL(TO_CHAR(p_id_obra), 'nula'));
        END;

        SELECT COUNT(*) INTO v_disponiveis
          FROM bib_exemplares
         WHERE id_obra = p_id_obra
           AND situacao = 'DISPONIVEL';

        IF v_disponiveis > 0 THEN
            RAISE_APPLICATION_ERROR(-20209,
                'Obra ' || p_id_obra || ' tem ' || v_disponiveis || ' exemplar(es) disponível(is): empreste direto');
        END IF;

        BEGIN
            INSERT INTO bib_reservas (id_obra, id_leitor, data_reserva)
            VALUES (p_id_obra, p_id_leitor, p_data)
            RETURNING id_reserva INTO v_id;
        EXCEPTION
            -- O índice único de reserva aberta é quem garante; aqui só se traduz a mensagem.
            WHEN DUP_VAL_ON_INDEX THEN
                RAISE_APPLICATION_ERROR(-20210,
                    'Leitor ' || p_id_leitor || ' já tem reserva aberta da obra ' || p_id_obra);
        END;

        RETURN v_id;
    END reservar;

    -- -------------------------------------------------------------------------
    PROCEDURE cancelar_reserva (
        p_id_reserva IN bib_reservas.id_reserva%TYPE,
        p_data       IN DATE DEFAULT TRUNC(SYSDATE)
    ) IS
        v_situacao    bib_reservas.situacao%TYPE;
        v_id_exemplar bib_reservas.id_exemplar%TYPE;
    BEGIN
        SAVEPOINT sp_bib_cancelar;

        BEGIN
            SELECT situacao, id_exemplar INTO v_situacao, v_id_exemplar
              FROM bib_reservas
             WHERE id_reserva = p_id_reserva
               FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20213, 'Reserva inexistente: ' || p_id_reserva);
        END;

        IF v_situacao NOT IN ('ATIVA', 'DISPONIVEL') THEN
            RAISE_APPLICATION_ERROR(-20213, 'Reserva ' || p_id_reserva || ' já está ' || v_situacao);
        END IF;

        UPDATE bib_reservas SET situacao = 'CANCELADA' WHERE id_reserva = p_id_reserva;

        IF v_situacao = 'DISPONIVEL' THEN
            liberar_exemplar(v_id_exemplar, p_data);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sp_bib_cancelar;
            RAISE;
    END cancelar_reserva;

    -- -------------------------------------------------------------------------
    FUNCTION expirar_reservas (p_data IN DATE DEFAULT TRUNC(SYSDATE)) RETURN PLS_INTEGER IS
        v_qtd PLS_INTEGER := 0;
    BEGIN
        FOR r IN (SELECT id_reserva, id_exemplar
                    FROM bib_reservas
                   WHERE situacao = 'DISPONIVEL'
                     AND prazo_retirada < TRUNC(p_data)
                     FOR UPDATE)
        LOOP
            UPDATE bib_reservas SET situacao = 'EXPIRADA' WHERE id_reserva = r.id_reserva;
            liberar_exemplar(r.id_exemplar, p_data);
            v_qtd := v_qtd + 1;
        END LOOP;
        RETURN v_qtd;
    END expirar_reservas;

    -- -------------------------------------------------------------------------
    FUNCTION pagar_multas (p_id_leitor IN bib_leitores.id_leitor%TYPE) RETURN NUMBER IS
        v_total NUMBER := multa_pendente(p_id_leitor);
    BEGIN
        UPDATE bib_emprestimos
           SET multa_paga = 'S'
         WHERE id_leitor = p_id_leitor
           AND valor_multa > 0
           AND multa_paga = 'N';
        RETURN v_total;
    END pagar_multas;

END bib_pkg_biblioteca;
/

SHOW ERRORS PACKAGE BODY bib_pkg_biblioteca
