-- =============================================================================
-- Tópico : Bind variables no SQL*Plus — VARIABLE, EXEC, PRINT, AUTOPRINT,
--          REFCURSOR, data como texto, um cursor para vários valores
-- Seção  : 12-sqlplus-sqlcl
-- Versão : 19c (SQL*Plus ou SQLcl)
-- Requer : schema de exemplo (00-ambiente); leitura de V$SQL no passo 5
-- =============================================================================

SET SERVEROUTPUT ON

-- 1. Declarar, atribuir, usar.
VARIABLE id_cliente NUMBER
EXEC :id_cliente := 3

SELECT nome, cidade FROM clientes WHERE id_cliente = :id_cliente;
-- Esperado: Escritorio Modelo SA | Belo Horizonte

PRINT id_cliente
-- Esperado: ID_CLIENTE 3

-- 2. Data: não há tipo DATE para bind; texto convertido na consulta.
VARIABLE data_ini VARCHAR2(10)
VARIABLE data_fim VARCHAR2(10)
EXEC :data_ini := '2026-01-01'
EXEC :data_fim := '2026-12-31'

SELECT COUNT(*) AS pedidos_2026
  FROM pedidos
 WHERE data_pedido >= TO_DATE(:data_ini, 'YYYY-MM-DD')
   AND data_pedido <  TO_DATE(:data_fim, 'YYYY-MM-DD') + 1;
-- Esperado: 8 (1017 a 1024)

-- 3. Valor calculado num bloco PL/SQL e usado depois.
VARIABLE total NUMBER
VARIABLE qtd   NUMBER

BEGIN
    SELECT COUNT(DISTINCT p.id_pedido),
           SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2))
      INTO :qtd, :total
      FROM pedidos p
      JOIN itens_pedido i ON i.id_pedido = p.id_pedido
     WHERE p.id_cliente = :id_cliente;
END;
/

PRINT qtd total
-- Esperado: QTD 3 | TOTAL 28994.22

-- AUTOPRINT: mostra sozinho as variáveis usadas no bloco.
SET AUTOPRINT ON
EXEC :total := :total * 1.1
-- Esperado: TOTAL 31893.642
SET AUTOPRINT OFF

-- 4. REFCURSOR: resultado de um SELECT guardado e impresso depois.
VARIABLE rc REFCURSOR

BEGIN
    OPEN :rc FOR
        SELECT id_pedido, status FROM pedidos WHERE id_cliente = :id_cliente ORDER BY id_pedido;
END;
/

PRINT rc
-- Esperado: 1002 ENTREGUE | 1009 ENTREGUE | 1017 ENTREGUE

-- 5. Um cursor, vários valores (o que a aplicação faz).
EXEC :id_cliente := 1
SELECT /* tmp_bind_sqlplus */ COUNT(*) FROM pedidos WHERE id_cliente = :id_cliente;
EXEC :id_cliente := 3
SELECT /* tmp_bind_sqlplus */ COUNT(*) FROM pedidos WHERE id_cliente = :id_cliente;
EXEC :id_cliente := 10
SELECT /* tmp_bind_sqlplus */ COUNT(*) FROM pedidos WHERE id_cliente = :id_cliente;

-- O mesmo com substituição: três textos diferentes.
DEFINE v_id = 1
SELECT /* tmp_subst_sqlplus */ COUNT(*) FROM pedidos WHERE id_cliente = &v_id;
DEFINE v_id = 3
SELECT /* tmp_subst_sqlplus */ COUNT(*) FROM pedidos WHERE id_cliente = &v_id;
DEFINE v_id = 10
SELECT /* tmp_subst_sqlplus */ COUNT(*) FROM pedidos WHERE id_cliente = &v_id;
UNDEFINE v_id

-- Esperado: tmp_bind_sqlplus 1 cursor com 3 execuções | tmp_subst_sqlplus 3 cursores
SELECT CASE WHEN sql_text LIKE '%tmp_bind_sqlplus%' THEN 'bind' ELSE 'substituição' END AS forma,
       COUNT(*)        AS cursores,
       SUM(executions) AS execucoes
  FROM v$sql
 WHERE (sql_text LIKE 'SELECT /* tmp_bind_sqlplus */%' OR sql_text LIKE 'SELECT /* tmp_subst_sqlplus */%')
 GROUP BY CASE WHEN sql_text LIKE '%tmp_bind_sqlplus%' THEN 'bind' ELSE 'substituição' END;

-- 6. Passar um valor de bind para variável de substituição (nome de arquivo, PROMPT).
COLUMN total_txt NEW_VALUE v_total NOPRINT
SELECT TO_CHAR(:total, 'FM999999990D00') AS total_txt FROM dual;
PROMPT Total com reajuste: &v_total
-- Esperado: Total com reajuste: 31893.64 (ou com vírgula, conforme o NLS)
COLUMN total_txt CLEAR
UNDEFINE v_total

-- 7. Listar as variáveis declaradas.
VARIABLE
