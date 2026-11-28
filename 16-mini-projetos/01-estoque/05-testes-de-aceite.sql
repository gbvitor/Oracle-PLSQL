-- =============================================================================
-- Projeto : 01 — Controle de estoque — testes de aceite
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : instalação completa com a carga de exemplo (04-carga.sql)
--
-- Cada teste imprime OK ou FALHOU; no fim, o total. O script termina com
-- ROLLBACK: os testes não alteram os dados carregados.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    v_total   PLS_INTEGER := 0;
    v_falhas  PLS_INTEGER := 0;
    v_id      NUMBER;
    v_qtd     NUMBER;
    v_antes   NUMBER;

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

    FUNCTION qtd_movimentos RETURN NUMBER IS
        v NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v FROM est_movimentos;
        RETURN v;
    END qtd_movimentos;
BEGIN
    -- T01 a T03: saldos da carga.
    conferir('T01 saldo do produto 1 no depósito 1 = 45', est_pkg_estoque.saldo(1, 1) = 45);
    conferir('T02 saldo do produto 1 em todos os depósitos = 57', est_pkg_estoque.saldo(1) = 57);
    conferir('T03 saldo fracionado do produto 5 no depósito 2 = 113,25', est_pkg_estoque.saldo(5, 2) = 113.25);

    -- T04: a carga gerou 16 movimentos (5 entradas, 2 transferências de 2 linhas, 5 saídas, 2 ajustes).
    conferir('T04 16 movimentos na carga', qtd_movimentos = 16);

    -- T05: saída maior que o saldo é recusada e nada muda.
    v_antes := qtd_movimentos;
    BEGIN
        v_id := est_pkg_estoque.saida(1, 1, 46, 'TESTE');
        conferir('T05 saída acima do saldo recusada', FALSE);
    EXCEPTION
        WHEN est_pkg_estoque.e_saldo_insuficiente THEN
            conferir('T05 saída acima do saldo recusada (ORA-20101)',
                     est_pkg_estoque.saldo(1, 1) = 45 AND qtd_movimentos = v_antes);
        WHEN OTHERS THEN
            conferir('T05 erro inesperado: ' || SQLERRM, FALSE);
    END;

    -- T06: saída de exatamente o saldo é aceita e zera o depósito.
    v_id := est_pkg_estoque.saida(1, 2, 12, 'TESTE');
    conferir('T06 saída do saldo inteiro deixa zero', est_pkg_estoque.saldo(1, 2) = 0);

    -- T07: quantidade zero, negativa, nula ou com mais de 3 casas é recusada.
    FOR r IN (SELECT 0 AS q FROM dual UNION ALL SELECT -5 FROM dual
              UNION ALL SELECT NULL FROM dual UNION ALL SELECT 1.2345 FROM dual) LOOP
        BEGIN
            v_id := est_pkg_estoque.entrada(1, 1, r.q, 'TESTE');
            conferir('T07 quantidade ' || NVL(TO_CHAR(r.q), 'nula') || ' recusada', FALSE);
        EXCEPTION
            WHEN est_pkg_estoque.e_quantidade_invalida THEN
                conferir('T07 quantidade ' || NVL(TO_CHAR(r.q), 'nula') || ' recusada (ORA-20102)', TRUE);
            WHEN OTHERS THEN
                conferir('T07 erro inesperado: ' || SQLERRM, FALSE);
        END;
    END LOOP;

    -- T08: produto inativo e produto inexistente são recusados.
    BEGIN
        v_id := est_pkg_estoque.entrada(6, 1, 10, 'TESTE');
        conferir('T08 produto inativo recusado', FALSE);
    EXCEPTION
        WHEN est_pkg_estoque.e_produto_invalido THEN
            conferir('T08 produto inativo recusado (ORA-20103)', TRUE);
        WHEN OTHERS THEN
            conferir('erro inesperado: ' || SQLERRM, FALSE);
    END;

    BEGIN
        v_id := est_pkg_estoque.entrada(999, 1, 10, 'TESTE');
        conferir('T09 produto inexistente recusado', FALSE);
    EXCEPTION
        WHEN est_pkg_estoque.e_produto_invalido THEN
            conferir('T09 produto inexistente recusado (ORA-20103)', TRUE);
        WHEN OTHERS THEN
            conferir('erro inesperado: ' || SQLERRM, FALSE);
    END;

    -- T10: depósito inexistente é recusado.
    BEGIN
        v_id := est_pkg_estoque.entrada(1, 9, 10, 'TESTE');
        conferir('T10 depósito inexistente recusado', FALSE);
    EXCEPTION
        WHEN est_pkg_estoque.e_deposito_invalido THEN
            conferir('T10 depósito inexistente recusado (ORA-20104)', TRUE);
        WHEN OTHERS THEN
            conferir('erro inesperado: ' || SQLERRM, FALSE);
    END;

    -- T11: entrada num depósito sem saldo ainda cria a linha de saldo.
    v_id := est_pkg_estoque.entrada(3, 2, 10, 'TESTE');
    conferir('T11 primeira entrada no depósito cria o saldo', est_pkg_estoque.saldo(3, 2) = 10);

    -- T12: transferência para o mesmo depósito é recusada.
    BEGIN
        v_id := est_pkg_estoque.transferir(1, 1, 1, 5, 'TESTE');
        conferir('T12 transferência para o mesmo depósito recusada', FALSE);
    EXCEPTION
        WHEN est_pkg_estoque.e_mesmo_deposito THEN
            conferir('T12 transferência para o mesmo depósito recusada (ORA-20105)', TRUE);
        WHEN OTHERS THEN
            conferir('erro inesperado: ' || SQLERRM, FALSE);
    END;

    -- T13: transferência sem saldo na origem não grava nada nos dois lados.
    v_antes := qtd_movimentos;
    BEGIN
        v_id := est_pkg_estoque.transferir(2, 1, 2, 9, 'TESTE');
        conferir('T13 transferência sem saldo recusada', FALSE);
    EXCEPTION
        WHEN est_pkg_estoque.e_saldo_insuficiente THEN
            conferir('T13 transferência sem saldo recusada e atômica',
                     qtd_movimentos = v_antes
                     AND est_pkg_estoque.saldo(2, 1) = 8
                     AND est_pkg_estoque.saldo(2, 2) = 0);
        WHEN OTHERS THEN
            conferir('erro inesperado: ' || SQLERRM, FALSE);
    END;

    -- T14: transferência válida grava as duas linhas com o mesmo id_transferencia.
    v_id := est_pkg_estoque.transferir(5, 1, 2, 49.5, 'TESTE');
    SELECT COUNT(*) INTO v_qtd FROM est_movimentos WHERE id_transferencia = v_id;
    conferir('T14 transferência grava saída e entrada ligadas',
             v_qtd = 2
             AND est_pkg_estoque.saldo(5, 1) = 300
             AND est_pkg_estoque.saldo(5, 2) = 162.75
             AND est_pkg_estoque.saldo(5) = 462.75);

    -- T15: ajuste com a contagem igual ao saldo não grava movimento.
    v_antes := qtd_movimentos;
    v_id := est_pkg_estoque.ajustar(3, 1, 47, 'Recontagem');
    conferir('T15 ajuste sem diferença não grava', v_id IS NULL AND qtd_movimentos = v_antes);

    -- T16: ajuste para menos e para zero.
    v_id := est_pkg_estoque.ajustar(3, 1, 0, 'Perda total');
    SELECT sinal * quantidade INTO v_qtd FROM est_movimentos WHERE id_movimento = v_id;
    conferir('T16 ajuste para zero grava -47', v_qtd = -47 AND est_pkg_estoque.saldo(3, 1) = 0);

    -- T17: ajuste sem motivo é recusado.
    BEGIN
        v_id := est_pkg_estoque.ajustar(4, 1, 25, '   ');
        conferir('T17 ajuste sem motivo recusado', FALSE);
    EXCEPTION
        WHEN est_pkg_estoque.e_motivo_obrigatorio THEN
            conferir('T17 ajuste sem motivo recusado (ORA-20106)', TRUE);
        WHEN OTHERS THEN
            conferir('erro inesperado: ' || SQLERRM, FALSE);
    END;

    -- T18: saldo materializado bate com a soma dos movimentos.
    SELECT COUNT(*)
      INTO v_qtd
      FROM est_saldos s
      FULL OUTER JOIN (SELECT id_produto, id_deposito, SUM(sinal * quantidade) AS qtd
                         FROM est_movimentos
                        GROUP BY id_produto, id_deposito) m
        ON m.id_produto = s.id_produto AND m.id_deposito = s.id_deposito
     WHERE NVL(s.quantidade, 0) <> NVL(m.qtd, 0);
    conferir('T18 saldo = soma dos movimentos em todos os pares', v_qtd = 0);

    -- T19: o kardex termina no saldo atual.
    SELECT saldo
      INTO v_qtd
      FROM est_vw_kardex
     WHERE id_produto = 1 AND id_deposito = 1
     ORDER BY data_movimento DESC, id_movimento DESC
     FETCH FIRST 1 ROW ONLY;
    conferir('T19 última linha do kardex = saldo', v_qtd = est_pkg_estoque.saldo(1, 1));

    -- T20: abaixo do mínimo, no estado em que os testes deixaram: produto 2 (8 de 10)
    -- e produto 4 (19 de 20). O produto 3 tem 0 no depósito 1, mas 10 no depósito 2 (mínimo 5).
    SELECT COUNT(*), SUM(CASE WHEN id_produto IN (2, 4) THEN 1 ELSE 0 END)
      INTO v_qtd, v_antes
      FROM est_vw_abaixo_minimo;
    conferir('T20 só os produtos 2 e 4 abaixo do mínimo', v_qtd = 2 AND v_antes = 2);

    -- T21: o CHECK barra saldo negativo mesmo por UPDATE direto.
    BEGIN
        UPDATE est_saldos SET quantidade = -1 WHERE id_produto = 1 AND id_deposito = 1;
        conferir('T21 CHECK barra saldo negativo', FALSE);
    EXCEPTION
        WHEN OTHERS THEN
            conferir('T21 CHECK barra saldo negativo (ORA-02290)', SQLCODE = -2290);
    END;

    DBMS_OUTPUT.PUT_LINE('----');
    DBMS_OUTPUT.PUT_LINE(v_total - v_falhas || ' de ' || v_total || ' testes passaram');
END;
/

ROLLBACK;
