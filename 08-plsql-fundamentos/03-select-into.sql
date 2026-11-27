-- =============================================================================
-- Tópico : SELECT INTO, NO_DATA_FOUND e TOO_MANY_ROWS
-- Seção  : 08-plsql-fundamentos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); CREATE PROCEDURE para o passo 6
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- 1. Uma linha: funciona.
DECLARE
    v_nome clientes.nome%TYPE;
    v_uf   clientes.uf%TYPE;
BEGIN
    SELECT nome, uf INTO v_nome, v_uf FROM clientes WHERE id_cliente = 6;
    DBMS_OUTPUT.PUT_LINE(v_nome || ' - ' || v_uf);
END;
/
-- Esperado: Colegio Saber Ltda - TO

-- 2. Nenhuma linha.
DECLARE
    v_nome clientes.nome%TYPE;
BEGIN
    SELECT nome INTO v_nome FROM clientes WHERE id_cliente = 999;
END;
/
-- Esperado: ORA-01403 (dados não encontrados)

-- 3. Mais de uma linha.
DECLARE
    v_nome clientes.nome%TYPE;
BEGIN
    SELECT nome INTO v_nome FROM clientes WHERE uf = 'SP';
END;
/
-- Esperado: ORA-01422 (a extração exata retorna mais do que o número solicitado de linhas)

-- 4. Tratando as duas, com SQLCODE de cada uma.
DECLARE
    v_nome clientes.nome%TYPE;

    PROCEDURE buscar(p_uf VARCHAR2) IS
    BEGIN
        SELECT nome INTO v_nome FROM clientes WHERE uf = p_uf;
        DBMS_OUTPUT.PUT_LINE(p_uf || ': ' || v_nome);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE(p_uf || ': nenhum cliente (SQLCODE ' || SQLCODE || ')');
        WHEN TOO_MANY_ROWS THEN
            DBMS_OUTPUT.PUT_LINE(p_uf || ': mais de um cliente (SQLCODE ' || SQLCODE || ')');
    END;
BEGIN
    buscar('MG');
    buscar('AM');
    buscar('SP');
END;
/
-- Esperado:
--   MG: Escritorio Modelo SA
--   AM: nenhum cliente (SQLCODE 100)
--   SP: mais de um cliente (SQLCODE -1422)

-- 5. Agregação nunca dá NO_DATA_FOUND.
DECLARE
    v_qtd    NUMBER;
    v_ultimo DATE;
BEGIN
    SELECT COUNT(*), MAX(data_pedido) INTO v_qtd, v_ultimo FROM pedidos WHERE id_cliente = 12;
    DBMS_OUTPUT.PUT_LINE('Pedidos: ' || v_qtd || ' | ultimo: [' || v_ultimo || ']');

    -- "Existe?" sem exceção, parando na primeira linha.
    SELECT COUNT(*) INTO v_qtd FROM pedidos WHERE id_cliente = 1 AND ROWNUM = 1;
    DBMS_OUTPUT.PUT_LINE('Cliente 1 tem pedido: ' || CASE v_qtd WHEN 1 THEN 'sim' ELSE 'nao' END);
END;
/
-- Esperado:
--   Pedidos: 0 | ultimo: []
--   Cliente 1 tem pedido: sim

-- 6. NO_DATA_FOUND silencioso em função chamada por SQL.
CREATE OR REPLACE FUNCTION tmp_fn_nome_cliente (p_id NUMBER) RETURN VARCHAR2 IS
    v_nome clientes.nome%TYPE;
BEGIN
    SELECT nome INTO v_nome FROM clientes WHERE id_cliente = p_id;
    RETURN v_nome;
END;
/

-- Chamada por SQL: o id 999 não existe, e o resultado é nulo, sem erro.
-- Esperado: 1 Papelaria Central Ltda | 999 (nulo)
SELECT id, tmp_fn_nome_cliente(id) AS nome
  FROM (SELECT 1 AS id FROM dual UNION ALL SELECT 999 FROM dual);

-- Chamada por PL/SQL: o erro aparece.
DECLARE
    v_nome VARCHAR2(100);
BEGIN
    v_nome := tmp_fn_nome_cliente(999);
END;
/
-- Esperado: ORA-01403 (dados não encontrados), com ORA-06512 apontando a função

-- Correção: tratar dentro da função e decidir o comportamento.
CREATE OR REPLACE FUNCTION tmp_fn_nome_cliente (p_id NUMBER) RETURN VARCHAR2 IS
    v_nome clientes.nome%TYPE;
BEGIN
    SELECT nome INTO v_nome FROM clientes WHERE id_cliente = p_id;
    RETURN v_nome;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN '(cliente ' || p_id || ' inexistente)';
END;
/

-- Esperado: 999 (cliente 999 inexistente)
SELECT id, tmp_fn_nome_cliente(id) AS nome
  FROM (SELECT 1 AS id FROM dual UNION ALL SELECT 999 FROM dual);

DROP FUNCTION tmp_fn_nome_cliente;

-- 7. SELECT INTO para registro %ROWTYPE.
DECLARE
    v_pedido pedidos%ROWTYPE;
BEGIN
    SELECT * INTO v_pedido FROM pedidos WHERE id_pedido = 1002;
    DBMS_OUTPUT.PUT_LINE('Pedido ' || v_pedido.id_pedido || ' | ' || v_pedido.status
                         || ' | obs: ' || v_pedido.observacao);
END;
/
-- Esperado: Pedido 1002 | ENTREGUE | obs: Entregar no 3o andar
