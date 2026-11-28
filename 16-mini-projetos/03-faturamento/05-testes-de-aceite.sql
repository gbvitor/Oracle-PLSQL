-- =============================================================================
-- Projeto : 03 — Faturamento simplificado — testes de aceite
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
    v_nota    NUMBER;
    v_valor   NUMBER;
    v_valor2  NUMBER;
    v_texto   VARCHAR2(30);

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

    FUNCTION nota (p_numero IN NUMBER) RETURN NUMBER IS
        v NUMBER;
    BEGIN
        SELECT id_nota INTO v FROM fat_notas WHERE serie = '1' AND numero = p_numero;
        RETURN v;
    END nota;

    FUNCTION titulo (p_numero IN NUMBER, p_parcela IN NUMBER) RETURN NUMBER IS
        v NUMBER;
    BEGIN
        SELECT t.id_titulo INTO v
          FROM fat_titulos t
          JOIN fat_notas n ON n.id_nota = t.id_nota
         WHERE n.serie = '1' AND n.numero = p_numero AND t.parcela = p_parcela;
        RETURN v;
    END titulo;
BEGIN
    -- T01: parcelas da nota 1 (30/60/90, 33,33% + 33,33% + 33,34%): a última absorve o arredondamento.
    SELECT SUM(CASE parcela WHEN 1 THEN valor END),
           SUM(CASE parcela WHEN 3 THEN valor END)
      INTO v_valor, v_valor2
      FROM fat_titulos WHERE id_nota = nota(1);
    conferir('T01 nota 1: parcelas 441,27 e última 441,39', v_valor = 441.27 AND v_valor2 = 441.39);

    -- T02: soma dos títulos = total da nota, em todas as notas.
    SELECT COUNT(*) INTO v_valor
      FROM fat_notas n
     WHERE n.valor_total <> (SELECT SUM(t.valor) FROM fat_titulos t WHERE t.id_nota = n.id_nota);
    conferir('T02 soma das parcelas = total em todas as notas', v_valor = 0);

    -- T03: encargos da baixa parcial da carga (500,00 com 10 dias): 11,50.
    SELECT encargos INTO v_valor
      FROM fat_baixas WHERE id_titulo = titulo(2, 1);
    conferir('T03 encargos da baixa com 10 dias de atraso = 11,50', v_valor = 11.5);

    -- T04: função de encargos.
    conferir('T04 encargos: 1000 com 10 dias = 23; no prazo = 0',
             fat_pkg_faturamento.encargos(1000, DATE '2026-11-01', DATE '2026-11-11') = 23
             AND fat_pkg_faturamento.encargos(1000, DATE '2026-11-01', DATE '2026-11-01') = 0);

    -- T05: limite de crédito. Cliente 2: 440,50 em aberto + 2.697,00 > 3.000,00.
    BEGIN
        v_nota := fat_pkg_faturamento.faturar(4, '1', c_hoje);
        conferir('T05 limite de crédito barra o faturamento', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T05 limite de crédito barra o faturamento', -20304, SQLCODE, SQLERRM);
    END;

    -- T06: a recusa não consumiu número: o contador continua em 3.
    SELECT ultimo_numero INTO v_valor FROM fat_numeracao WHERE serie = '1';
    conferir('T06 faturamento recusado não consome número', v_valor = 3);

    -- T07: quitando o saldo da nota 2 (440,50, 39 dias de atraso), o pedido 4 passa.
    --      Encargos: 440,50 x (2% + 0,03% x 39) = 13,96.
    v_id := fat_pkg_faturamento.baixar(titulo(2, 1), 440.50, c_hoje);
    SELECT b.encargos, t.situacao INTO v_valor, v_texto
      FROM fat_baixas b JOIN fat_titulos t ON t.id_titulo = b.id_titulo
     WHERE b.id_baixa = v_id;
    conferir('T07 quitação com encargos 13,96 e título PAGO', v_valor = 13.96 AND v_texto = 'PAGO');

    v_nota := fat_pkg_faturamento.faturar(4, '1', c_hoje);
    SELECT numero, valor_total INTO v_valor, v_valor2 FROM fat_notas WHERE id_nota = v_nota;
    conferir('T08 pedido 4 faturado como nota 4, total 2.697,00', v_valor = 4 AND v_valor2 = 2697);

    SELECT em_aberto, disponivel INTO v_valor, v_valor2 FROM fat_vw_posicao_cliente WHERE id_cliente = 2;
    conferir('T09 cliente 2: em aberto 2.697,00, disponível 303,00', v_valor = 2697 AND v_valor2 = 303);

    -- T10: pedido já faturado, pedido sem itens, cliente inativo, série inexistente.
    BEGIN
        v_nota := fat_pkg_faturamento.faturar(4, '1', c_hoje);
        conferir('T10 pedido já faturado recusado', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T10 pedido já faturado recusado', -20301, SQLCODE, SQLERRM);
    END;

    BEGIN
        v_nota := fat_pkg_faturamento.faturar(5, '1', c_hoje);
        conferir('T11 pedido sem itens recusado', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T11 pedido sem itens recusado', -20302, SQLCODE, SQLERRM);
    END;

    BEGIN
        v_nota := fat_pkg_faturamento.faturar(6, '1', c_hoje);
        conferir('T12 cliente inativo recusado', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T12 cliente inativo recusado', -20303, SQLCODE, SQLERRM);
    END;

    -- Pedido novo só para o teste de série.
    INSERT INTO fat_pedidos (id_pedido, id_cliente, id_condicao, data_pedido) VALUES (7, 1, 1, c_hoje);
    INSERT INTO fat_itens_pedido VALUES (7, 1, 1, 1, 120.00, 0);
    BEGIN
        v_nota := fat_pkg_faturamento.faturar(7, '9', c_hoje);
        conferir('T13 série inexistente recusada', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T13 série inexistente recusada', -20311, SQLCODE, SQLERRM);
    END;

    -- T14: a falha da série desfez tudo do faturamento: pedido 7 continua ABERTO.
    SELECT situacao INTO v_texto FROM fat_pedidos WHERE id_pedido = 7;
    conferir('T14 faturamento com erro não deixa resto', v_texto = 'ABERTO');

    -- T15 a T17: validações da baixa.
    BEGIN
        v_id := fat_pkg_faturamento.baixar(titulo(1, 2), 500, c_hoje);
        conferir('T15 baixa maior que o saldo recusada', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T15 baixa maior que o saldo recusada', -20308, SQLCODE, SQLERRM);
    END;

    BEGIN
        v_id := fat_pkg_faturamento.baixar(titulo(1, 2), 0, c_hoje);
        conferir('T16 baixa de valor zero recusada', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T16 baixa de valor zero recusada', -20307, SQLCODE, SQLERRM);
    END;

    BEGIN
        v_id := fat_pkg_faturamento.baixar(titulo(1, 1), 10, c_hoje);
        conferir('T17 baixa de título pago recusada', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T17 baixa de título pago recusada', -20306, SQLCODE, SQLERRM);
    END;

    -- T18: duas baixas parciais quitam o título (antes do vencimento: sem encargos).
    v_id := fat_pkg_faturamento.baixar(titulo(1, 2), 200, c_hoje);
    SELECT situacao, valor - valor_pago INTO v_texto, v_valor FROM fat_titulos WHERE id_titulo = titulo(1, 2);
    conferir('T18 baixa parcial: saldo 241,27, título ABERTO', v_texto = 'ABERTO' AND v_valor = 241.27);

    v_id := fat_pkg_faturamento.baixar(titulo(1, 2), 241.27, c_hoje);
    SELECT situacao INTO v_texto FROM fat_titulos WHERE id_titulo = titulo(1, 2);
    conferir('T19 segunda baixa quita o título', v_texto = 'PAGO');

    -- T20: nota com baixa não cancela.
    BEGIN
        fat_pkg_faturamento.cancelar_nota(nota(1), 'Teste');
        conferir('T20 nota com baixa não cancela', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T20 nota com baixa não cancela', -20305, SQLCODE, SQLERRM);
    END;

    -- T21: cancelamento sem motivo.
    BEGIN
        fat_pkg_faturamento.cancelar_nota(nota(3), ' ');
        conferir('T21 cancelamento sem motivo recusado', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T21 cancelamento sem motivo recusado', -20310, SQLCODE, SQLERRM);
    END;

    -- T22: nota 3 cancelada: títulos cancelados, pedido 3 volta a ABERTO.
    fat_pkg_faturamento.cancelar_nota(nota(3), 'Erro de digitação no pedido');
    SELECT COUNT(*) INTO v_valor FROM fat_titulos WHERE id_nota = nota(3) AND situacao = 'CANCELADO';
    SELECT situacao INTO v_texto FROM fat_pedidos WHERE id_pedido = 3;
    conferir('T22 nota 3 cancelada, 2 títulos cancelados, pedido aberto', v_valor = 2 AND v_texto = 'ABERTO');

    -- T23: refaturado, o pedido 3 ganha o número 5; o 3 fica como nota cancelada.
    v_nota := fat_pkg_faturamento.faturar(3, '1', c_hoje);
    SELECT numero INTO v_valor FROM fat_notas WHERE id_nota = v_nota;
    conferir('T23 refaturamento usa o próximo número (5)', v_valor = 5);

    -- T24: numeração contínua: 5 notas, números 1 a 5, sem buraco.
    SELECT COUNT(*), MIN(numero), MAX(numero) INTO v_id, v_valor, v_valor2 FROM fat_notas WHERE serie = '1';
    conferir('T24 numeração 1 a 5 sem buraco', v_id = 5 AND v_valor = 1 AND v_valor2 = 5);

    -- T25: o índice único parcial barra uma segunda nota emitida para o mesmo pedido.
    BEGIN
        INSERT INTO fat_notas (serie, numero, id_pedido, id_cliente, data_emissao, valor_total)
        VALUES ('1', 99, 1, 1, c_hoje, 10);
        conferir('T25 segunda nota emitida do mesmo pedido barrada', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T25 segunda nota emitida do mesmo pedido barrada', -1, SQLCODE, SQLERRM);
    END;

    -- T26: valor pago de cada título = soma das suas baixas.
    SELECT COUNT(*) INTO v_valor
      FROM fat_titulos t
     WHERE t.valor_pago <> NVL((SELECT SUM(b.valor) FROM fat_baixas b WHERE b.id_titulo = t.id_titulo), 0);
    conferir('T26 valor pago = soma das baixas em todos os títulos', v_valor = 0);

    DBMS_OUTPUT.PUT_LINE('----');
    DBMS_OUTPUT.PUT_LINE(v_total - v_falhas || ' de ' || v_total || ' testes passaram');
END;
/

ROLLBACK;
