-- =============================================================================
-- Tópico : Cursores explícitos — OPEN, FETCH, CLOSE e atributos
-- Seção  : 08-plsql-fundamentos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- 1. Ciclo completo: pedidos do cliente 1 com o valor líquido.
DECLARE
    CURSOR c_pedidos IS
        SELECT p.id_pedido,
               p.status,
               SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
          FROM pedidos p
          JOIN itens_pedido i ON i.id_pedido = p.id_pedido
         WHERE p.id_cliente = 1
         GROUP BY p.id_pedido, p.status
         ORDER BY p.id_pedido;

    r c_pedidos%ROWTYPE;
BEGIN
    OPEN c_pedidos;
    DBMS_OUTPUT.PUT_LINE('Depois do OPEN: ROWCOUNT = ' || c_pedidos%ROWCOUNT);

    LOOP
        FETCH c_pedidos INTO r;
        EXIT WHEN c_pedidos%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(r.id_pedido || ' ' || RPAD(r.status, 9) || ' ' || r.valor);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Total buscado: ' || c_pedidos%ROWCOUNT);
    CLOSE c_pedidos;
END;
/
-- Esperado:
--   Depois do OPEN: ROWCOUNT = 0
--   1001 ENTREGUE  1045.5
--   1006 ENTREGUE  2046
--   1015 ENTREGUE  1311.5
--   1022 ABERTO    1513
--   Total buscado: 4

-- 2. FETCH para variáveis soltas, em vez de record.
DECLARE
    CURSOR c_vendedores IS
        SELECT nome, pct_comissao FROM funcionarios WHERE cargo = 'Vendedor' ORDER BY nome;

    v_nome     funcionarios.nome%TYPE;
    v_comissao funcionarios.pct_comissao%TYPE;
BEGIN
    OPEN c_vendedores;
    LOOP
        FETCH c_vendedores INTO v_nome, v_comissao;
        EXIT WHEN c_vendedores%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(v_nome || ': ' || v_comissao || '%');
    END LOOP;
    CLOSE c_vendedores;
END;
/
-- Esperado:
--   Eduarda Lima: 5%
--   Felipe Souza: 5%
--   Gabriela Rocha: 4%
--   Henrique Alves: 3%

-- 3. A armadilha: EXIT WHEN no lugar errado repete a última linha.
DECLARE
    CURSOR c IS SELECT id_pedido FROM pedidos WHERE id_cliente = 8 ORDER BY id_pedido;
    v_id pedidos.id_pedido%TYPE;
BEGIN
    OPEN c;
    LOOP
        FETCH c INTO v_id;
        DBMS_OUTPUT.PUT_LINE('Processando ' || v_id);
        EXIT WHEN c%NOTFOUND;
    END LOOP;
    CLOSE c;
END;
/
-- Esperado: Processando 1007 | Processando 1018 | Processando 1018
--           (o cliente 8 tem dois pedidos; o terceiro FETCH não traz nada e
--            a variável continua com 1018)

-- 4. A mesma leitura com WHILE: FETCH antes do laço e no fim de cada volta.
DECLARE
    CURSOR c IS SELECT id_pedido FROM pedidos WHERE id_cliente = 8 ORDER BY id_pedido;
    v_id pedidos.id_pedido%TYPE;
BEGIN
    OPEN c;
    FETCH c INTO v_id;
    WHILE c%FOUND LOOP
        DBMS_OUTPUT.PUT_LINE('Processando ' || v_id);
        FETCH c INTO v_id;
    END LOOP;
    CLOSE c;
END;
/
-- Esperado: Processando 1007 | Processando 1018

-- 5. Erros de ciclo de vida.
DECLARE
    CURSOR c IS SELECT id_cliente FROM clientes;
    v_id clientes.id_cliente%TYPE;
BEGIN
    OPEN c;
    OPEN c;
END;
/
-- Esperado: ORA-06511: PL/SQL: cursor já aberto (CURSOR_ALREADY_OPEN)

DECLARE
    CURSOR c IS SELECT id_cliente FROM clientes;
    v_id clientes.id_cliente%TYPE;
BEGIN
    OPEN c;
    CLOSE c;
    FETCH c INTO v_id;
END;
/
-- Esperado: ORA-01001: cursor inválido (INVALID_CURSOR)

DECLARE
    CURSOR c IS SELECT id_cliente FROM clientes;
BEGIN
    DBMS_OUTPUT.PUT_LINE('ISOPEN antes do OPEN: ' || CASE WHEN c%ISOPEN THEN 'TRUE' ELSE 'FALSE' END);
    DBMS_OUTPUT.PUT_LINE('ROWCOUNT antes do OPEN: ' || c%ROWCOUNT);
END;
/
-- Esperado: ISOPEN antes do OPEN: FALSE, depois ORA-01001
--           (só %ISOPEN pode ser consultado com o cursor fechado)

-- 6. O resultado é fixado no OPEN: mudanças feitas depois não aparecem.
CREATE TABLE tmp_produtos AS SELECT * FROM produtos;

DECLARE
    CURSOR c IS
        SELECT id_produto, preco_unitario FROM tmp_produtos WHERE id_categoria = 5 ORDER BY id_produto;
    r c%ROWTYPE;
BEGIN
    OPEN c;

    UPDATE tmp_produtos SET preco_unitario = preco_unitario * 2 WHERE id_categoria = 5;
    DBMS_OUTPUT.PUT_LINE('UPDATE feito depois do OPEN: ' || SQL%ROWCOUNT || ' linhas');

    LOOP
        FETCH c INTO r;
        EXIT WHEN c%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('Cursor: ' || r.id_produto || ' -> ' || r.preco_unitario);
    END LOOP;
    CLOSE c;
END;
/
-- Esperado:
--   UPDATE feito depois do OPEN: 3 linhas
--   Cursor: 8 -> 32.5
--   Cursor: 9 -> 45
--   Cursor: 10 -> 27.8
--   (preços de antes do UPDATE, embora a própria sessão tenha alterado)

-- Esperado: 65 | 90 | 55.6 (a tabela, consultada agora, já tem os novos)
SELECT id_produto, preco_unitario FROM tmp_produtos WHERE id_categoria = 5 ORDER BY id_produto;

ROLLBACK;
DROP TABLE tmp_produtos PURGE;

-- 7. Fechar no tratador de exceção.
DECLARE
    CURSOR c IS SELECT id_pedido FROM pedidos ORDER BY id_pedido;
    v_id   pedidos.id_pedido%TYPE;
    v_zero PLS_INTEGER := 0;
BEGIN
    OPEN c;
    FETCH c INTO v_id;
    v_id := v_id / v_zero;
    CLOSE c;
EXCEPTION
    WHEN ZERO_DIVIDE THEN
        IF c%ISOPEN THEN
            CLOSE c;
            DBMS_OUTPUT.PUT_LINE('Erro tratado e cursor fechado');
        END IF;
END;
/
-- Esperado: Erro tratado e cursor fechado
