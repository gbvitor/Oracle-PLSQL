-- =============================================================================
-- Projeto : 02 — Biblioteca — testes de aceite
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : instalação completa com a carga de exemplo (04-carga.sql)
--
-- Os testes são uma sequência: cada um parte do estado deixado pelo anterior.
-- Data de referência: 28/11/2026. O script termina com ROLLBACK.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    c_hoje    CONSTANT DATE := DATE '2026-11-28';
    v_total   PLS_INTEGER := 0;
    v_falhas  PLS_INTEGER := 0;
    v_id      NUMBER;
    v_valor   NUMBER;
    v_texto   VARCHAR2(30);
    v_data    DATE;

    PROCEDURE conferir (p_teste IN VARCHAR2, p_ok IN BOOLEAN) IS
    BEGIN
        v_total := v_total + 1;
        IF NVL(p_ok, FALSE) THEN
            DBMS_OUTPUT.PUT_LINE('OK      ' || p_teste);
        ELSE
            v_falhas := v_falhas + 1;
            DBMS_OUTPUT.PUT_LINE('FALHOU  ' || p_teste);
        END IF;
    END conferir;

    -- Confere que o erro capturado é o esperado. SQLCODE e SQLERRM são passados
    -- pelo handler que capturou o erro.
    PROCEDURE conferir_erro (
        p_teste    IN VARCHAR2,
        p_esperado IN PLS_INTEGER,
        p_sqlcode  IN PLS_INTEGER,
        p_sqlerrm  IN VARCHAR2
    ) IS
    BEGIN
        conferir(p_teste || ' (ORA-' || TO_CHAR(-p_esperado, 'FM00000') || ')'
                 || CASE WHEN p_sqlcode <> p_esperado THEN ' — veio: ' || p_sqlerrm END,
                 p_sqlcode = p_esperado);
    END conferir_erro;

    FUNCTION situacao_exemplar (p_id IN NUMBER) RETURN VARCHAR2 IS
        v bib_exemplares.situacao%TYPE;
    BEGIN
        SELECT situacao INTO v FROM bib_exemplares WHERE id_exemplar = p_id;
        RETURN v;
    END situacao_exemplar;

    FUNCTION emprestimo_aberto (p_id_exemplar IN NUMBER) RETURN NUMBER IS
        v NUMBER;
    BEGIN
        SELECT id_emprestimo INTO v
          FROM bib_emprestimos
         WHERE id_exemplar = p_id_exemplar AND data_devolucao IS NULL;
        RETURN v;
    END emprestimo_aberto;
BEGIN
    -- T01: estado da carga.
    SELECT COUNT(*) INTO v_valor FROM bib_emprestimos WHERE data_devolucao IS NULL;
    conferir('T01 carga: 2 empréstimos abertos e multa de 4,50 do leitor 2',
             v_valor = 2 AND bib_pkg_biblioteca.multa_pendente(2) = 4.5);

    -- T02: multa pendente impede empréstimo.
    BEGIN
        v_id := bib_pkg_biblioteca.emprestar(2, 101, c_hoje);
        conferir('T02 multa pendente bloqueia', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T02 multa pendente bloqueia', -20203, SQLCODE, SQLERRM);
    END;

    -- T03: pagando a multa, o empréstimo sai, com prazo de 7 dias (aluno).
    v_valor := bib_pkg_biblioteca.pagar_multas(2);
    v_id    := bib_pkg_biblioteca.emprestar(2, 101, c_hoje);
    SELECT data_prevista INTO v_data FROM bib_emprestimos WHERE id_emprestimo = v_id;
    conferir('T03 pagou 4,50 e emprestou com prevista 05/12',
             v_valor = 4.5 AND v_data = DATE '2026-12-05' AND situacao_exemplar(101) = 'EMPRESTADO');

    -- T04: limite de 3 empréstimos para aluno.
    v_id := bib_pkg_biblioteca.emprestar(2, 301, c_hoje);
    v_id := bib_pkg_biblioteca.emprestar(2, 501, c_hoje);
    BEGIN
        v_id := bib_pkg_biblioteca.emprestar(2, 502, c_hoje);
        conferir('T04 quarto empréstimo do aluno recusado', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T04 quarto empréstimo do aluno recusado', -20202, SQLCODE, SQLERRM);
    END;

    -- T05: empréstimo em atraso (201, previsto 20/11) impede outro.
    BEGIN
        v_id := bib_pkg_biblioteca.emprestar(1, 503, c_hoje);
        conferir('T05 leitor com atraso bloqueado', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T05 leitor com atraso bloqueado', -20204, SQLCODE, SQLERRM);
    END;

    -- T06: exemplar emprestado e exemplar baixado não saem.
    BEGIN
        v_id := bib_pkg_biblioteca.emprestar(3, 102, c_hoje);
        conferir('T06 exemplar já emprestado recusado', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T06 exemplar já emprestado recusado', -20205, SQLCODE, SQLERRM);
    END;

    BEGIN
        v_id := bib_pkg_biblioteca.emprestar(3, 401, c_hoje);
        conferir('T07 exemplar baixado recusado', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T07 exemplar baixado recusado', -20205, SQLCODE, SQLERRM);
    END;

    -- T08: leitor inativo.
    BEGIN
        v_id := bib_pkg_biblioteca.emprestar(4, 502, c_hoje);
        conferir('T08 leitor inativo recusado', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T08 leitor inativo recusado', -20201, SQLCODE, SQLERRM);
    END;

    -- T09: o índice único barra um segundo empréstimo aberto do mesmo exemplar,
    --      mesmo gravando direto na tabela, sem a package.
    BEGIN
        INSERT INTO bib_emprestimos (id_exemplar, id_leitor, data_emprestimo, data_prevista)
        VALUES (102, 5, c_hoje, c_hoje + 7);
        conferir('T09 índice único barra empréstimo duplicado', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T09 índice único barra empréstimo duplicado', -1, SQLCODE, SQLERRM);
    END;

    -- T10: empréstimo em atraso não renova.
    BEGIN
        bib_pkg_biblioteca.renovar(emprestimo_aberto(201), c_hoje);
        conferir('T10 renovação em atraso recusada', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T10 renovação em atraso recusada', -20206, SQLCODE, SQLERRM);
    END;

    -- T11: professor renova a segunda vez (prevista 28/11 + 14 = 12/12); a terceira passa do limite.
    v_id := emprestimo_aberto(102);
    bib_pkg_biblioteca.renovar(v_id, c_hoje);
    SELECT data_prevista, renovacoes INTO v_data, v_valor FROM bib_emprestimos WHERE id_emprestimo = v_id;
    conferir('T11 segunda renovação: prevista 12/12', v_data = DATE '2026-12-12' AND v_valor = 2);

    BEGIN
        bib_pkg_biblioteca.renovar(v_id, c_hoje);
        conferir('T12 terceira renovação recusada', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T12 terceira renovação recusada', -20207, SQLCODE, SQLERRM);
    END;

    -- T13: reserva da obra 3 (único exemplar com o leitor 2); com fila, o leitor 2 não renova.
    v_id := bib_pkg_biblioteca.reservar(3, 3, c_hoje);
    SELECT posicao INTO v_valor FROM bib_vw_fila_reservas WHERE id_reserva = v_id;
    conferir('T13 reserva da obra 3 entra na posição 1', v_valor = 1);

    BEGIN
        bib_pkg_biblioteca.renovar(emprestimo_aberto(301), c_hoje);
        conferir('T14 renovação com fila recusada', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T14 renovação com fila recusada', -20208, SQLCODE, SQLERRM);
    END;

    -- T15: não se reserva obra com exemplar disponível (obra 5: 502 e 503).
    BEGIN
        v_id := bib_pkg_biblioteca.reservar(1, 5, c_hoje);
        conferir('T15 reserva de obra disponível recusada', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T15 reserva de obra disponível recusada', -20209, SQLCODE, SQLERRM);
    END;

    -- T16: segunda reserva aberta do mesmo leitor para a mesma obra.
    BEGIN
        v_id := bib_pkg_biblioteca.reservar(3, 2, c_hoje);
        conferir('T16 reserva duplicada recusada', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T16 reserva duplicada recusada', -20210, SQLCODE, SQLERRM);
    END;

    -- T17: devolução com 8 dias de atraso (20/11 a 28/11) a 1,50: 12,00.
    --      O exemplar vai para o primeiro da fila (Professor 01), com prazo até 30/11.
    v_valor := bib_pkg_biblioteca.devolver(201, c_hoje);
    SELECT situacao, prazo_retirada INTO v_texto, v_data
      FROM bib_reservas
     WHERE id_obra = 2 AND id_leitor = 3 AND situacao IN ('ATIVA', 'DISPONIVEL');
    conferir('T17 devolução atrasada: multa 12 e exemplar separado para a fila',
             v_valor = 12 AND v_texto = 'DISPONIVEL' AND v_data = DATE '2026-11-30'
             AND situacao_exemplar(201) = 'RESERVADO');

    -- T18: exemplar separado não sai para outro leitor.
    BEGIN
        v_id := bib_pkg_biblioteca.emprestar(5, 201, c_hoje);
        conferir('T18 exemplar reservado para outro recusado', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T18 exemplar reservado para outro recusado', -20205, SQLCODE, SQLERRM);
    END;

    -- T19: não retirada até 30/11, a reserva expira em 01/12; sem mais fila, o exemplar fica disponível.
    v_valor := bib_pkg_biblioteca.expirar_reservas(DATE '2026-12-01');
    conferir('T19 uma reserva expirada e exemplar 201 disponível',
             v_valor = 1 AND situacao_exemplar(201) = 'DISPONIVEL');

    -- T20: a multa nova (12,00) bloqueia o leitor 1.
    BEGIN
        v_id := bib_pkg_biblioteca.emprestar(1, 201, c_hoje);
        conferir('T20 multa da devolução atrasada bloqueia', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T20 multa da devolução atrasada bloqueia', -20203, SQLCODE, SQLERRM);
    END;

    -- T21: devolver exemplar que não está emprestado.
    BEGIN
        v_valor := bib_pkg_biblioteca.devolver(503, c_hoje);
        conferir('T21 devolução de exemplar não emprestado recusada', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T21 devolução de exemplar não emprestado recusada', -20211, SQLCODE, SQLERRM);
    END;

    -- T22: cancelar a reserva da obra 3; cancelar de novo é recusado.
    SELECT id_reserva INTO v_id FROM bib_reservas WHERE id_obra = 3 AND id_leitor = 3 AND situacao = 'ATIVA';
    bib_pkg_biblioteca.cancelar_reserva(v_id, c_hoje);
    BEGIN
        bib_pkg_biblioteca.cancelar_reserva(v_id, c_hoje);
        conferir('T22 reserva cancelada não cancela de novo', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T22 reserva cancelada não cancela de novo', -20213, SQLCODE, SQLERRM);
    END;

    -- T23: situação dos exemplares coerente com empréstimos e reservas.
    SELECT COUNT(*) INTO v_valor
      FROM bib_exemplares x
     WHERE (x.situacao = 'EMPRESTADO'
            AND NOT EXISTS (SELECT 1 FROM bib_emprestimos e
                             WHERE e.id_exemplar = x.id_exemplar AND e.data_devolucao IS NULL))
        OR (x.situacao <> 'EMPRESTADO'
            AND EXISTS (SELECT 1 FROM bib_emprestimos e
                         WHERE e.id_exemplar = x.id_exemplar AND e.data_devolucao IS NULL))
        OR (x.situacao = 'RESERVADO'
            AND NOT EXISTS (SELECT 1 FROM bib_reservas r
                             WHERE r.id_exemplar = x.id_exemplar AND r.situacao = 'DISPONIVEL'));
    conferir('T23 situação dos exemplares coerente com empréstimos e reservas', v_valor = 0);

    DBMS_OUTPUT.PUT_LINE('----');
    DBMS_OUTPUT.PUT_LINE(v_total - v_falhas || ' de ' || v_total || ' testes passaram');
END;
/

ROLLBACK;
