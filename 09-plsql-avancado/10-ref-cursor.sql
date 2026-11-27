-- =============================================================================
-- Tópico : REF CURSOR e SYS_REFCURSOR — devolver linhas, OPEN FOR dinâmico,
--          cursor forte e fraco, BULK COLLECT, consumo no SQL*Plus
-- Seção  : 09-plsql-avancado
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); CREATE PROCEDURE
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- 1. Function que devolve SYS_REFCURSOR: quem chama lê e fecha.
CREATE OR REPLACE FUNCTION tmp_fn_pedidos_cliente (p_id_cliente IN NUMBER)
    RETURN SYS_REFCURSOR
IS
    v_rc SYS_REFCURSOR;
BEGIN
    OPEN v_rc FOR
        SELECT p.id_pedido,
               p.status,
               SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
          FROM pedidos p
          JOIN itens_pedido i ON i.id_pedido = p.id_pedido
         WHERE p.id_cliente = p_id_cliente
         GROUP BY p.id_pedido, p.status
         ORDER BY p.id_pedido;
    RETURN v_rc;
END tmp_fn_pedidos_cliente;
/

DECLARE
    v_rc     SYS_REFCURSOR;
    v_id     pedidos.id_pedido%TYPE;
    v_status pedidos.status%TYPE;
    v_valor  NUMBER;
BEGIN
    v_rc := tmp_fn_pedidos_cliente(1);
    LOOP
        FETCH v_rc INTO v_id, v_status, v_valor;
        EXIT WHEN v_rc%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(v_id || ' ' || RPAD(v_status, 9) || ' ' || v_valor);
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Linhas: ' || v_rc%ROWCOUNT);
    CLOSE v_rc;
END;
/
-- Esperado:
--   1001 ENTREGUE  1045.5
--   1006 ENTREGUE  2046
--   1015 ENTREGUE  1311.5
--   1022 ABERTO    1513
--   Linhas: 4

-- 2. Consumo pelo SQL*Plus: variável REFCURSOR e PRINT.
VARIABLE rc REFCURSOR
EXEC :rc := tmp_fn_pedidos_cliente(10)
PRINT rc
-- Esperado: 1008 ENTREGUE 27286 | 1014 ENTREGUE 15962.7 | 1020 FATURADO 16832.88
--           (PRINT lê e fecha o cursor)

-- 3. Procedure com OUT SYS_REFCURSOR e ordenação escolhida por lista permitida.
CREATE OR REPLACE PROCEDURE tmp_proc_clientes (
    p_uf    IN  VARCHAR2,
    p_ordem IN  VARCHAR2,
    p_rc    OUT SYS_REFCURSOR
) IS
    v_coluna VARCHAR2(30);
BEGIN
    v_coluna := CASE UPPER(p_ordem)
                    WHEN 'NOME'   THEN 'nome'
                    WHEN 'LIMITE' THEN 'limite_credito DESC NULLS LAST'
                    ELSE 'id_cliente'
                END;

    OPEN p_rc FOR
        'SELECT id_cliente, nome, limite_credito FROM clientes WHERE uf = :uf ORDER BY ' || v_coluna
        USING p_uf;
END tmp_proc_clientes;
/

VARIABLE rc REFCURSOR
EXEC tmp_proc_clientes('SP', 'limite', :rc)
PRINT rc
-- Esperado: 1 Papelaria Central Ltda 50000 | 2 Tech Solucoes ME 30000 | 9 Fernanda Araujo 4000

EXEC tmp_proc_clientes('SP', 'nome; DROP TABLE clientes', :rc)
PRINT rc
-- Esperado: ordem por id_cliente (valor fora da lista cai no ELSE; nada é concatenado do parâmetro)

-- 4. BULK COLLECT de uma variável de cursor.
DECLARE
    v_rc SYS_REFCURSOR;
    TYPE t_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    TYPE t_txt IS TABLE OF VARCHAR2(12) INDEX BY PLS_INTEGER;
    v_ids    t_ids;
    v_status t_txt;
    v_valor  t_ids;
BEGIN
    v_rc := tmp_fn_pedidos_cliente(3);
    FETCH v_rc BULK COLLECT INTO v_ids, v_status, v_valor;
    CLOSE v_rc;

    DBMS_OUTPUT.PUT_LINE('Pedidos do cliente 3: ' || v_ids.COUNT);
    FOR i IN 1 .. v_ids.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || v_ids(i) || ' ' || v_valor(i));
    END LOOP;
END;
/
-- Esperado: Pedidos do cliente 3: 3 | 1002 16276.5 | 1009 5163.44 | 1017 7554.28

-- 5. Cursor forte: estrutura verificada na compilação.
DECLARE
    TYPE t_rc_pedidos IS REF CURSOR RETURN pedidos%ROWTYPE;
    v_rc t_rc_pedidos;
BEGIN
    OPEN v_rc FOR SELECT id_pedido, status FROM pedidos;
END;
/
-- Esperado: erro de compilação PLS-00382 (expressão do tipo incorreto)

-- 6. Cursor fraco: o erro de estrutura só aparece no FETCH.
DECLARE
    v_rc  SYS_REFCURSOR;
    r_ped pedidos%ROWTYPE;
BEGIN
    OPEN v_rc FOR SELECT id_pedido, status FROM pedidos;
    FETCH v_rc INTO r_ped;
EXCEPTION
    WHEN ROWTYPE_MISMATCH THEN
        DBMS_OUTPUT.PUT_LINE('FETCH em estrutura diferente: ROWTYPE_MISMATCH (' || SQLCODE || ')');
        CLOSE v_rc;
END;
/
-- Esperado: FETCH em estrutura diferente: ROWTYPE_MISMATCH (-6504)

-- 7. Variável de cursor como parâmetro de entrada: rotina genérica que só consome.
DECLARE
    v_rc SYS_REFCURSOR;

    PROCEDURE imprimir_id_nome (p_rc IN OUT SYS_REFCURSOR, p_titulo IN VARCHAR2) IS
        v_id   NUMBER;
        v_nome VARCHAR2(100);
    BEGIN
        DBMS_OUTPUT.PUT_LINE('-- ' || p_titulo);
        LOOP
            FETCH p_rc INTO v_id, v_nome;
            EXIT WHEN p_rc%NOTFOUND;
            DBMS_OUTPUT.PUT_LINE(v_id || ' ' || v_nome);
        END LOOP;
        CLOSE p_rc;
    END;
BEGIN
    OPEN v_rc FOR SELECT id_departamento, nome FROM departamentos WHERE cidade = 'Sao Paulo' ORDER BY 1;
    imprimir_id_nome(v_rc, 'Departamentos em São Paulo');

    OPEN v_rc FOR SELECT id_categoria, nome FROM categorias WHERE id_categoria_pai IS NULL ORDER BY 1;
    imprimir_id_nome(v_rc, 'Categorias raiz');
END;
/
-- Esperado:
--   -- Departamentos em São Paulo
--   10 Diretoria
--   20 Comercial
--   -- Categorias raiz
--   1 Informatica
--   4 Escritorio

-- 8. Variável de cursor não pode ficar no nível da package.
CREATE OR REPLACE PACKAGE tmp_pkg_rc IS
    TYPE t_rc IS REF CURSOR;
    g_rc t_rc;
END tmp_pkg_rc;
/
-- Esperado: criado com erros; SHOW ERRORS mostra PLS-00994
--           (variáveis de cursor não podem ser declaradas como parte de um pacote)
SHOW ERRORS PACKAGE tmp_pkg_rc

DROP PACKAGE tmp_pkg_rc;
DROP PROCEDURE tmp_proc_clientes;
DROP FUNCTION tmp_fn_pedidos_cliente;
