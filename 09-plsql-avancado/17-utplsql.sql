-- =============================================================================
-- Tópico : Testes unitários com utPLSQL
-- Seção  : 09-plsql-avancado
-- Versão : 19c, utPLSQL 3.x
-- Requer : schema de exemplo (00-ambiente); utPLSQL instalado no banco pelo DBA
--          (instruções em 17-utplsql.md). Não funciona no FreeSQL.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- Conferir a instalação.
-- Esperado: v3.x.x...
SELECT ut.version() FROM dual;

-- -----------------------------------------------------------------------------
-- Código a testar
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION tmp_fn_valor_liquido (
    p_quantidade IN NUMBER,
    p_preco      IN NUMBER,
    p_desconto   IN NUMBER DEFAULT 0
) RETURN NUMBER IS
BEGIN
    IF p_desconto < 0 OR p_desconto > 100 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Desconto fora de 0 a 100: ' || p_desconto);
    END IF;
    RETURN ROUND(p_quantidade * p_preco * (1 - NVL(p_desconto, 0) / 100), 2);
END tmp_fn_valor_liquido;
/

CREATE OR REPLACE FUNCTION tmp_fn_pedidos_do_cliente (p_id_cliente IN NUMBER)
    RETURN SYS_REFCURSOR
IS
    v_rc SYS_REFCURSOR;
BEGIN
    OPEN v_rc FOR
        SELECT id_pedido, status FROM pedidos WHERE id_cliente = p_id_cliente ORDER BY id_pedido;
    RETURN v_rc;
END tmp_fn_pedidos_do_cliente;
/

-- -----------------------------------------------------------------------------
-- Suite de testes
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE tmp_test_vendas IS
    --%suite(Regras de venda)

    --%context(Valor líquido do item)

    --%test(Sem desconto: quantidade vezes preço)
    PROCEDURE sem_desconto;

    --%test(Com desconto e arredondamento em 2 casas)
    PROCEDURE com_desconto;

    --%test(Desconto nulo é tratado como zero)
    PROCEDURE desconto_nulo;

    --%test(Desconto acima de 100 é recusado)
    --%throws(-20001)
    PROCEDURE desconto_acima_de_100;

    --%test(Bate com o total geral dos itens de exemplo)
    PROCEDURE total_geral;

    --%endcontext

    --%context(Pedidos do cliente)

    --%test(Cliente 8 tem o cancelado e o entregue, em ordem)
    PROCEDURE pedidos_cliente_8;

    --%test(Cliente sem pedidos devolve cursor vazio)
    PROCEDURE cliente_sem_pedidos;

    --%endcontext
END tmp_test_vendas;
/

CREATE OR REPLACE PACKAGE BODY tmp_test_vendas IS

    PROCEDURE sem_desconto IS
    BEGIN
        ut.expect(tmp_fn_valor_liquido(20, 29.90, 0)).to_equal(598);
    END sem_desconto;

    PROCEDURE com_desconto IS
    BEGIN
        ut.expect(tmp_fn_valor_liquido(10, 25, 5)).to_equal(237.5);
        ut.expect(tmp_fn_valor_liquido(3, 33.33, 10)).to_equal(89.99);
    END com_desconto;

    PROCEDURE desconto_nulo IS
    BEGIN
        ut.expect(tmp_fn_valor_liquido(2, 39.90, NULL)).to_equal(79.8);
    END desconto_nulo;

    PROCEDURE desconto_acima_de_100 IS
        v NUMBER;
    BEGIN
        v := tmp_fn_valor_liquido(1, 10, 101);
    END desconto_acima_de_100;

    PROCEDURE total_geral IS
        v_total NUMBER;
    BEGIN
        SELECT SUM(tmp_fn_valor_liquido(quantidade, preco_unitario, pct_desconto))
          INTO v_total
          FROM itens_pedido;
        ut.expect(v_total).to_equal(122815.43);
    END total_geral;

    PROCEDURE pedidos_cliente_8 IS
        v_real     SYS_REFCURSOR;
        v_esperado SYS_REFCURSOR;
    BEGIN
        v_real := tmp_fn_pedidos_do_cliente(8);
        OPEN v_esperado FOR
            SELECT 1007 AS id_pedido, CAST('CANCELADO' AS VARCHAR2(12)) AS status FROM dual
            UNION ALL
            SELECT 1018, CAST('ENTREGUE' AS VARCHAR2(12)) FROM dual;
        ut.expect(v_real).to_equal(v_esperado);
    END pedidos_cliente_8;

    PROCEDURE cliente_sem_pedidos IS
    BEGIN
        ut.expect(tmp_fn_pedidos_do_cliente(11)).to_be_empty();
    END cliente_sem_pedidos;

END tmp_test_vendas;
/

-- -----------------------------------------------------------------------------
-- Executar
-- -----------------------------------------------------------------------------
EXEC ut.run('tmp_test_vendas')
-- Esperado (formato do relatório padrão, tempos variam):
--   Regras de venda
--     Valor líquido do item
--       Sem desconto: quantidade vezes preço [...]
--       Com desconto e arredondamento em 2 casas [...]
--       Desconto nulo é tratado como zero [...]
--       Desconto acima de 100 é recusado [...]
--       Bate com o total geral dos itens de exemplo [...]
--     Pedidos do cliente
--       Cliente 8 tem o cancelado e o entregue, em ordem [...]
--       Cliente sem pedidos devolve cursor vazio [...]
--   Finished in ... seconds
--   7 tests, 0 failed, 0 errored, 0 disabled, 0 warning(s)
--
-- O CAST no cursor esperado existe porque literal de texto é CHAR e a coluna é
-- VARCHAR2; a comparação de cursores do utPLSQL também compara os tipos.

-- Ver um teste falhando: mude a expectativa de sem_desconto para 599 e rode de novo.
-- O relatório mostra "Actual: 598 (number) was expected to equal: 599 (number)".

DROP PACKAGE tmp_test_vendas;
DROP FUNCTION tmp_fn_pedidos_do_cliente;
DROP FUNCTION tmp_fn_valor_liquido;
