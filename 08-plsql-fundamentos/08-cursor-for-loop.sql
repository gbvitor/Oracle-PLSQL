-- =============================================================================
-- Tópico : Cursor FOR loop, cursores com parâmetro, FOR UPDATE e WHERE CURRENT OF
-- Seção  : 08-plsql-fundamentos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- 1. Cursor FOR loop com a consulta no próprio laço.
--    Coluna calculada precisa de alias para virar campo do record.
BEGIN
    FOR r IN (SELECT c.id_cliente,
                     c.nome,
                     COUNT(p.id_pedido) AS qtd_pedidos
                FROM clientes c
                LEFT JOIN pedidos p
                  ON p.id_cliente = c.id_cliente
                 AND p.status <> 'CANCELADO'
               WHERE c.uf = 'SP'
               GROUP BY c.id_cliente, c.nome
               ORDER BY c.id_cliente)
    LOOP
        DBMS_OUTPUT.PUT_LINE(r.id_cliente || ' ' || r.nome || ': ' || r.qtd_pedidos || ' pedidos');
    END LOOP;
END;
/
-- Esperado:
--   1 Papelaria Central Ltda: 4 pedidos
--   2 Tech Solucoes ME: 3 pedidos
--   9 Fernanda Araujo: 2 pedidos

-- 2. O record do laço só existe dentro do laço.
BEGIN
    FOR r IN (SELECT nome FROM clientes WHERE id_cliente = 1) LOOP
        NULL;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE(r.nome);
END;
/
-- Esperado: erro de compilação PLS-00201 (identificador 'R.NOME' deve ser declarado)

-- 3. Cursor com parâmetro e valor padrão.
DECLARE
    CURSOR c_clientes (p_uf    clientes.uf%TYPE,
                       p_ativo clientes.ativo%TYPE DEFAULT 'S') IS
        SELECT id_cliente, nome
          FROM clientes
         WHERE uf = p_uf
           AND ativo = p_ativo
         ORDER BY id_cliente;

    v_qtd PLS_INTEGER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('-- SP, ativos (padrão)');
    FOR r IN c_clientes('SP') LOOP
        DBMS_OUTPUT.PUT_LINE(r.id_cliente || ' ' || r.nome);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('-- CE, inativos (notação nomeada)');
    FOR r IN c_clientes(p_uf => 'CE', p_ativo => 'N') LOOP
        DBMS_OUTPUT.PUT_LINE(r.id_cliente || ' ' || r.nome);
    END LOOP;

    v_qtd := 0;
    FOR r IN c_clientes('CE') LOOP
        v_qtd := v_qtd + 1;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('-- CE, ativos: ' || v_qtd || ' linhas');
END;
/
-- Esperado:
--   -- SP, ativos (padrão)
--   1 Papelaria Central Ltda
--   2 Tech Solucoes ME
--   9 Fernanda Araujo
--   -- CE, inativos (notação nomeada)
--   11 Loja Antiga ME
--   -- CE, ativos: 0 linhas

-- 4. %ROWCOUNT de um cursor nomeado dentro do FOR loop.
DECLARE
    CURSOR c IS SELECT nome FROM funcionarios WHERE id_departamento = 40 ORDER BY salario DESC;
BEGIN
    FOR r IN c LOOP
        DBMS_OUTPUT.PUT_LINE(c%ROWCOUNT || 'o: ' || r.nome);
    END LOOP;
END;
/
-- Esperado: 1o: Diego Martins | 2o: Lucas Fernandes | 3o: Marina Gomes

-- 5. O mesmo cursor aberto uma vez por volta do laço externo (padrão N+1).
DECLARE
    CURSOR c_func (p_depto funcionarios.id_departamento%TYPE) IS
        SELECT id_funcionario FROM funcionarios WHERE id_departamento = p_depto;

    v_qtd PLS_INTEGER;
BEGIN
    FOR d IN (SELECT id_departamento, nome FROM departamentos ORDER BY id_departamento) LOOP
        v_qtd := 0;
        FOR f IN c_func(d.id_departamento) LOOP
            v_qtd := v_qtd + 1;
        END LOOP;
        DBMS_OUTPUT.PUT_LINE(d.nome || ': ' || v_qtd);
    END LOOP;
END;
/
-- Esperado: Diretoria: 1 | Comercial: 6 | Financeiro: 3 | Logistica: 3 | Marketing: 0
--           (6 consultas; a versão com uma só é o LEFT JOIN com COUNT do passo 1)

-- 6. FOR UPDATE e WHERE CURRENT OF: reajuste por faixa de preço.
CREATE TABLE tmp_produtos AS SELECT * FROM produtos;

DECLARE
    CURSOR c IS
        SELECT id_produto, preco_unitario
          FROM tmp_produtos
         WHERE id_categoria = 2
           AND ativo = 'S'
           FOR UPDATE OF preco_unitario NOWAIT;
BEGIN
    FOR r IN c LOOP
        UPDATE tmp_produtos
           SET preco_unitario = ROUND(r.preco_unitario * CASE WHEN r.preco_unitario < 100 THEN 1.10 ELSE 1.05 END, 2)
         WHERE CURRENT OF c;
    END LOOP;
END;
/

-- Esperado: 1 -> 43.89 | 2 -> 98.89 | 3 -> 943.95 | 4 -> 262.4 | 15 -> 79.9 (inativo, não mexeu)
SELECT id_produto, preco_unitario FROM tmp_produtos WHERE id_categoria = 2 ORDER BY id_produto;

ROLLBACK;

-- 7. COMMIT dentro do laço de um cursor FOR UPDATE.
DECLARE
    CURSOR c IS
        SELECT id_produto, preco_unitario
          FROM tmp_produtos
         WHERE id_categoria = 2
         ORDER BY id_produto
           FOR UPDATE;

    r c%ROWTYPE;
BEGIN
    OPEN c;
    LOOP
        FETCH c INTO r;
        EXIT WHEN c%NOTFOUND;
        UPDATE tmp_produtos SET preco_unitario = preco_unitario + 1 WHERE CURRENT OF c;
        DBMS_OUTPUT.PUT_LINE('Gravado: ' || r.id_produto);
        COMMIT;
    END LOOP;
    CLOSE c;
END;
/
-- Esperado: Gravado: 1, depois ORA-01002 (busca fora de sequência) na busca seguinte ao COMMIT.
--           A linha 1 ficou gravada: o COMMIT já tinha acontecido.

-- Esperado: 40.9 (39.90 + 1, persistido pelo COMMIT do laço)
SELECT preco_unitario FROM tmp_produtos WHERE id_produto = 1;

DROP TABLE tmp_produtos PURGE;
