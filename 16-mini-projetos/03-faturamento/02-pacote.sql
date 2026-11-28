-- =============================================================================
-- Projeto : 03 — Faturamento simplificado — package FAT_PKG_FATURAMENTO
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : 01-tabelas.sql; CREATE PROCEDURE
--
-- Pedido -> nota (numeração sem buraco) -> títulos (parcelas) -> baixas.
-- Sem COMMIT: quem chama decide a transação. Datas como parâmetro.
-- =============================================================================

CREATE OR REPLACE PACKAGE fat_pkg_faturamento AS

    -- Encargos de atraso: multa única sobre o valor pago e juros por dia de atraso.
    c_multa      CONSTANT NUMBER := 0.02;
    c_juros_dia  CONSTANT NUMBER := 0.0003;

    e_pedido_nao_aberto     EXCEPTION;  PRAGMA EXCEPTION_INIT(e_pedido_nao_aberto,     -20301);
    e_pedido_sem_itens      EXCEPTION;  PRAGMA EXCEPTION_INIT(e_pedido_sem_itens,      -20302);
    e_cliente_inativo       EXCEPTION;  PRAGMA EXCEPTION_INIT(e_cliente_inativo,       -20303);
    e_limite_credito        EXCEPTION;  PRAGMA EXCEPTION_INIT(e_limite_credito,        -20304);
    e_nota_com_baixa        EXCEPTION;  PRAGMA EXCEPTION_INIT(e_nota_com_baixa,        -20305);
    e_titulo_nao_aberto     EXCEPTION;  PRAGMA EXCEPTION_INIT(e_titulo_nao_aberto,     -20306);
    e_valor_invalido        EXCEPTION;  PRAGMA EXCEPTION_INIT(e_valor_invalido,        -20307);
    e_valor_acima_do_saldo  EXCEPTION;  PRAGMA EXCEPTION_INIT(e_valor_acima_do_saldo,  -20308);
    e_nota_nao_emitida      EXCEPTION;  PRAGMA EXCEPTION_INIT(e_nota_nao_emitida,      -20309);
    e_motivo_obrigatorio    EXCEPTION;  PRAGMA EXCEPTION_INIT(e_motivo_obrigatorio,    -20310);
    e_serie_inexistente     EXCEPTION;  PRAGMA EXCEPTION_INIT(e_serie_inexistente,     -20311);
    e_condicao_invalida     EXCEPTION;  PRAGMA EXCEPTION_INIT(e_condicao_invalida,     -20312);

    -- Gera a nota e os títulos do pedido. Devolve o id da nota.
    FUNCTION faturar (
        p_id_pedido IN fat_pedidos.id_pedido%TYPE,
        p_serie     IN fat_numeracao.serie%TYPE DEFAULT '1',
        p_data      IN DATE DEFAULT TRUNC(SYSDATE)
    ) RETURN fat_notas.id_nota%TYPE;

    -- Cancela a nota sem baixa: títulos cancelados, pedido volta a ABERTO.
    -- O número cancelado não é reaproveitado.
    PROCEDURE cancelar_nota (
        p_id_nota IN fat_notas.id_nota%TYPE,
        p_motivo  IN VARCHAR2
    );

    -- Registra um pagamento (parcial ou total) do título. Devolve o id da baixa.
    FUNCTION baixar (
        p_id_titulo IN fat_titulos.id_titulo%TYPE,
        p_valor     IN NUMBER,
        p_data      IN DATE DEFAULT TRUNC(SYSDATE)
    ) RETURN fat_baixas.id_baixa%TYPE;

    -- Encargos de atraso sobre um valor pago em p_data com vencimento p_vencimento.
    FUNCTION encargos (
        p_valor      IN NUMBER,
        p_vencimento IN DATE,
        p_data       IN DATE
    ) RETURN NUMBER DETERMINISTIC;

    -- Soma dos saldos de títulos abertos do cliente.
    FUNCTION em_aberto (p_id_cliente IN fat_clientes.id_cliente%TYPE) RETURN NUMBER;

END fat_pkg_faturamento;
/

CREATE OR REPLACE PACKAGE BODY fat_pkg_faturamento AS

    FUNCTION encargos (
        p_valor      IN NUMBER,
        p_vencimento IN DATE,
        p_data       IN DATE
    ) RETURN NUMBER DETERMINISTIC IS
        v_dias NUMBER := TRUNC(p_data) - TRUNC(p_vencimento);
    BEGIN
        IF v_dias <= 0 THEN
            RETURN 0;
        END IF;
        RETURN ROUND(p_valor * (c_multa + c_juros_dia * v_dias), 2);
    END encargos;

    FUNCTION em_aberto (p_id_cliente IN fat_clientes.id_cliente%TYPE) RETURN NUMBER IS
        v_total NUMBER;
    BEGIN
        SELECT NVL(SUM(t.valor - t.valor_pago), 0)
          INTO v_total
          FROM fat_titulos t
          JOIN fat_notas n ON n.id_nota = t.id_nota
         WHERE n.id_cliente = p_id_cliente
           AND t.situacao = 'ABERTO';
        RETURN v_total;
    END em_aberto;

    -- -------------------------------------------------------------------------
    FUNCTION faturar (
        p_id_pedido IN fat_pedidos.id_pedido%TYPE,
        p_serie     IN fat_numeracao.serie%TYPE DEFAULT '1',
        p_data      IN DATE DEFAULT TRUNC(SYSDATE)
    ) RETURN fat_notas.id_nota%TYPE IS
        v_situacao    fat_pedidos.situacao%TYPE;
        v_id_cliente  fat_pedidos.id_cliente%TYPE;
        v_id_condicao fat_pedidos.id_condicao%TYPE;
        v_ativo       fat_clientes.ativo%TYPE;
        v_limite      fat_clientes.limite_credito%TYPE;
        v_itens       PLS_INTEGER;
        v_total       NUMBER;
        v_aberto      NUMBER;
        v_parcelas    PLS_INTEGER;
        v_pct_total   NUMBER;
        v_numero      fat_numeracao.ultimo_numero%TYPE;
        v_id_nota     fat_notas.id_nota%TYPE;
        v_valor       NUMBER;
        v_acumulado   NUMBER := 0;
    BEGIN
        SAVEPOINT sp_fat_faturar;

        -- Pedido travado: duas sessões não faturam o mesmo pedido.
        BEGIN
            SELECT situacao, id_cliente, id_condicao
              INTO v_situacao, v_id_cliente, v_id_condicao
              FROM fat_pedidos
             WHERE id_pedido = p_id_pedido
               FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20301, 'Pedido inexistente: ' || NVL(TO_CHAR(p_id_pedido), 'nulo'));
        END;

        IF v_situacao <> 'ABERTO' THEN
            RAISE_APPLICATION_ERROR(-20301, 'Pedido ' || p_id_pedido || ' está ' || v_situacao);
        END IF;

        -- Valor de cada item arredondado antes de somar: é o valor que vai impresso na nota.
        SELECT COUNT(*), NVL(SUM(ROUND(quantidade * preco_unitario * (1 - pct_desconto / 100), 2)), 0)
          INTO v_itens, v_total
          FROM fat_itens_pedido
         WHERE id_pedido = p_id_pedido;

        IF v_itens = 0 OR v_total = 0 THEN
            RAISE_APPLICATION_ERROR(-20302, 'Pedido ' || p_id_pedido || ' sem itens ou com total zero');
        END IF;

        -- Cliente travado: duas notas do mesmo cliente não passam juntas pelo limite.
        SELECT ativo, limite_credito
          INTO v_ativo, v_limite
          FROM fat_clientes
         WHERE id_cliente = v_id_cliente
           FOR UPDATE;

        IF v_ativo <> 'S' THEN
            RAISE_APPLICATION_ERROR(-20303, 'Cliente ' || v_id_cliente || ' inativo');
        END IF;

        v_aberto := em_aberto(v_id_cliente);
        IF v_limite IS NOT NULL AND v_aberto + v_total > v_limite THEN
            RAISE_APPLICATION_ERROR(-20304,
                'Limite de crédito: em aberto ' || TO_CHAR(v_aberto) || ' + nota ' || TO_CHAR(v_total)
                || ' > limite ' || TO_CHAR(v_limite));
        END IF;

        SELECT COUNT(*), NVL(SUM(percentual), 0)
          INTO v_parcelas, v_pct_total
          FROM fat_condicoes_parcelas
         WHERE id_condicao = v_id_condicao;

        IF v_parcelas = 0 OR v_pct_total <> 100 THEN
            RAISE_APPLICATION_ERROR(-20312,
                'Condição ' || v_id_condicao || ' com ' || v_parcelas || ' parcela(s) somando '
                || TO_CHAR(v_pct_total) || '%');
        END IF;

        -- Próximo número: o UPDATE trava a linha da série até o fim da transação.
        -- Faturamentos simultâneos da mesma série esperam um pelo outro, e um ROLLBACK
        -- devolve o número: não há buraco.
        UPDATE fat_numeracao
           SET ultimo_numero = ultimo_numero + 1
         WHERE serie = p_serie
        RETURNING ultimo_numero INTO v_numero;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20311, 'Série não cadastrada: ' || p_serie);
        END IF;

        INSERT INTO fat_notas (serie, numero, id_pedido, id_cliente, data_emissao, valor_total)
        VALUES (p_serie, v_numero, p_id_pedido, v_id_cliente, TRUNC(p_data), v_total)
        RETURNING id_nota INTO v_id_nota;

        INSERT INTO fat_itens_nota (id_nota, item, id_produto, quantidade, preco_unitario, pct_desconto, valor)
        SELECT v_id_nota, item, id_produto, quantidade, preco_unitario, pct_desconto,
               ROUND(quantidade * preco_unitario * (1 - pct_desconto / 100), 2)
          FROM fat_itens_pedido
         WHERE id_pedido = p_id_pedido;

        -- Parcelas: cada uma arredondada; a última recebe a diferença, para a soma
        -- dos títulos ser exatamente o total da nota.
        FOR r IN (SELECT numero, dias, percentual,
                         ROW_NUMBER() OVER (ORDER BY numero) AS rn,
                         COUNT(*) OVER ()                    AS qtd
                    FROM fat_condicoes_parcelas
                   WHERE id_condicao = v_id_condicao
                   ORDER BY numero)
        LOOP
            IF r.rn = r.qtd THEN
                v_valor := v_total - v_acumulado;
            ELSE
                v_valor := ROUND(v_total * r.percentual / 100, 2);
            END IF;
            v_acumulado := v_acumulado + v_valor;

            INSERT INTO fat_titulos (id_nota, parcela, vencimento, valor)
            VALUES (v_id_nota, r.rn, TRUNC(p_data) + r.dias, v_valor);
        END LOOP;

        UPDATE fat_pedidos SET situacao = 'FATURADO' WHERE id_pedido = p_id_pedido;

        RETURN v_id_nota;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sp_fat_faturar;
            RAISE;
    END faturar;

    -- -------------------------------------------------------------------------
    PROCEDURE cancelar_nota (
        p_id_nota IN fat_notas.id_nota%TYPE,
        p_motivo  IN VARCHAR2
    ) IS
        v_situacao  fat_notas.situacao%TYPE;
        v_id_pedido fat_notas.id_pedido%TYPE;
        v_baixas    PLS_INTEGER;
    BEGIN
        SAVEPOINT sp_fat_cancelar;

        IF TRIM(p_motivo) IS NULL THEN
            RAISE_APPLICATION_ERROR(-20310, 'Cancelamento exige motivo');
        END IF;

        BEGIN
            SELECT situacao, id_pedido INTO v_situacao, v_id_pedido
              FROM fat_notas
             WHERE id_nota = p_id_nota
               FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20309, 'Nota inexistente: ' || p_id_nota);
        END;

        IF v_situacao <> 'EMITIDA' THEN
            RAISE_APPLICATION_ERROR(-20309, 'Nota ' || p_id_nota || ' já está ' || v_situacao);
        END IF;

        SELECT COUNT(*) INTO v_baixas
          FROM fat_baixas b
          JOIN fat_titulos t ON t.id_titulo = b.id_titulo
         WHERE t.id_nota = p_id_nota;

        IF v_baixas > 0 THEN
            RAISE_APPLICATION_ERROR(-20305,
                'Nota ' || p_id_nota || ' tem ' || v_baixas || ' baixa(s): estorne antes de cancelar');
        END IF;

        UPDATE fat_titulos SET situacao = 'CANCELADO' WHERE id_nota = p_id_nota;
        UPDATE fat_notas
           SET situacao = 'CANCELADA', motivo_cancelamento = p_motivo
         WHERE id_nota = p_id_nota;
        UPDATE fat_pedidos SET situacao = 'ABERTO' WHERE id_pedido = v_id_pedido;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sp_fat_cancelar;
            RAISE;
    END cancelar_nota;

    -- -------------------------------------------------------------------------
    FUNCTION baixar (
        p_id_titulo IN fat_titulos.id_titulo%TYPE,
        p_valor     IN NUMBER,
        p_data      IN DATE DEFAULT TRUNC(SYSDATE)
    ) RETURN fat_baixas.id_baixa%TYPE IS
        v_situacao   fat_titulos.situacao%TYPE;
        v_valor      fat_titulos.valor%TYPE;
        v_pago       fat_titulos.valor_pago%TYPE;
        v_vencimento fat_titulos.vencimento%TYPE;
        v_id         fat_baixas.id_baixa%TYPE;
    BEGIN
        SAVEPOINT sp_fat_baixar;

        IF p_valor IS NULL OR p_valor <= 0 OR p_valor <> ROUND(p_valor, 2) THEN
            RAISE_APPLICATION_ERROR(-20307,
                'Valor de baixa inválido: ' || NVL(TO_CHAR(p_valor), 'nulo'));
        END IF;

        BEGIN
            SELECT situacao, valor, valor_pago, vencimento
              INTO v_situacao, v_valor, v_pago, v_vencimento
              FROM fat_titulos
             WHERE id_titulo = p_id_titulo
               FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20306, 'Título inexistente: ' || NVL(TO_CHAR(p_id_titulo), 'nulo'));
        END;

        IF v_situacao <> 'ABERTO' THEN
            RAISE_APPLICATION_ERROR(-20306, 'Título ' || p_id_titulo || ' está ' || v_situacao);
        END IF;

        IF p_valor > v_valor - v_pago THEN
            RAISE_APPLICATION_ERROR(-20308,
                'Pagamento ' || TO_CHAR(p_valor) || ' maior que o saldo ' || TO_CHAR(v_valor - v_pago));
        END IF;

        INSERT INTO fat_baixas (id_titulo, data_pagamento, valor, encargos)
        VALUES (p_id_titulo, TRUNC(p_data), p_valor, encargos(p_valor, v_vencimento, p_data))
        RETURNING id_baixa INTO v_id;

        -- No SET, valor_pago à direita é o valor de antes do UPDATE.
        UPDATE fat_titulos
           SET valor_pago = valor_pago + p_valor,
               situacao   = CASE WHEN valor_pago + p_valor = valor THEN 'PAGO' ELSE 'ABERTO' END
         WHERE id_titulo = p_id_titulo;

        RETURN v_id;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sp_fat_baixar;
            RAISE;
    END baixar;

END fat_pkg_faturamento;
/

SHOW ERRORS PACKAGE BODY fat_pkg_faturamento
