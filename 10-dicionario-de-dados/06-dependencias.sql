-- =============================================================================
-- Tópico : Dependências — quem usa esta tabela (direta e indiretamente),
--          do que um objeto depende, e o que a dependência não enxerga
-- Seção  : 10-dicionario-de-dados
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente), recém-instalado; CREATE VIEW,
--          CREATE PROCEDURE
-- =============================================================================

COLUMN dependente FORMAT A40
COLUMN name       FORMAT A24
COLUMN texto      FORMAT A60

-- Objetos de exemplo: uma cadeia sobre PEDIDOS e um uso por SQL dinâmico.
CREATE OR REPLACE VIEW tmp_vw_pedidos_valor AS
SELECT p.id_pedido,
       p.id_cliente,
       p.status,
       SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
  FROM pedidos p
  JOIN itens_pedido i ON i.id_pedido = p.id_pedido
 GROUP BY p.id_pedido, p.id_cliente, p.status;

CREATE OR REPLACE FUNCTION tmp_fn_total_cliente (p_id_cliente IN NUMBER) RETURN NUMBER IS
    v NUMBER;
BEGIN
    SELECT NVL(SUM(valor), 0) INTO v
      FROM tmp_vw_pedidos_valor
     WHERE id_cliente = p_id_cliente
       AND status <> 'CANCELADO';
    RETURN v;
END tmp_fn_total_cliente;
/

CREATE OR REPLACE PACKAGE tmp_pkg_relatorio IS
    PROCEDURE ranking;
END tmp_pkg_relatorio;
/

CREATE OR REPLACE PACKAGE BODY tmp_pkg_relatorio IS
    PROCEDURE ranking IS
    BEGIN
        FOR r IN (SELECT id_cliente, nome FROM clientes ORDER BY tmp_fn_total_cliente(id_cliente) DESC
                  FETCH FIRST 3 ROWS ONLY) LOOP
            DBMS_OUTPUT.PUT_LINE(r.nome || ': ' || tmp_fn_total_cliente(r.id_cliente));
        END LOOP;
    END ranking;
END tmp_pkg_relatorio;
/

CREATE OR REPLACE PROCEDURE tmp_proc_limpeza IS
BEGIN
    EXECUTE IMMEDIATE 'DELETE FROM pedidos WHERE status = ''CANCELADO'' AND data_pedido < SYSDATE - 3650';
END tmp_proc_limpeza;
/

-- 1. Quem usa PEDIDOS diretamente.
-- Esperado: TMP_VW_PEDIDOS_VALOR | VIEW (a function e a package usam a view, não a tabela;
--           a procedure de limpeza não aparece: SQL dinâmico)
SELECT name, type
  FROM user_dependencies
 WHERE referenced_name = 'PEDIDOS'
   AND referenced_type = 'TABLE'
   AND referenced_owner = USER
 ORDER BY name;

-- 2. Quem usa PEDIDOS direta ou indiretamente (árvore).
-- Esperado:
--   PEDIDOS (TABLE)
--     TMP_VW_PEDIDOS_VALOR (VIEW)
--       TMP_FN_TOTAL_CLIENTE (FUNCTION)
--         TMP_PKG_RELATORIO (PACKAGE BODY)
WITH dep (name, type, nivel, caminho) AS (
    SELECT CAST('PEDIDOS' AS VARCHAR2(128)), CAST('TABLE' AS VARCHAR2(30)), 1, CAST('PEDIDOS' AS VARCHAR2(4000))
      FROM dual
    UNION ALL
    SELECT d.name, d.type, p.nivel + 1, p.caminho || '>' || d.name
      FROM user_dependencies d
      JOIN dep p
        ON d.referenced_name  = p.name
       AND d.referenced_type  = p.type
       AND d.referenced_owner = USER
     WHERE p.nivel < 10
)
SEARCH DEPTH FIRST BY name SET ordem
SELECT LPAD(' ', 2 * (nivel - 1)) || name || ' (' || type || ')' AS dependente
  FROM dep
 ORDER BY ordem;

-- 3. Do que a package depende.
-- Esperado: CLIENTES TABLE | TMP_FN_TOTAL_CLIENTE FUNCTION | TMP_PKG_RELATORIO PACKAGE
--           (e DBMS_OUTPUT / STANDARD, do SYS, se o filtro de dono for retirado)
SELECT referenced_owner, referenced_name, referenced_type
  FROM user_dependencies
 WHERE name = 'TMP_PKG_RELATORIO'
   AND type = 'PACKAGE BODY'
   AND referenced_owner = USER
 ORDER BY referenced_name;

-- 4. O ponto cego: SQL dinâmico só aparece na busca de texto.
--    Busca simples com LIKE: acha o SQL dinâmico, mas também um falso positivo.
-- Esperado:
--   TMP_FN_TOTAL_CLIENTE FUNCTION  linha 5  FROM tmp_vw_pedidos_valor   (falso positivo:
--                                                                        "PEDIDOS" dentro do nome da view)
--   TMP_PROC_LIMPEZA     PROCEDURE linha 3  EXECUTE IMMEDIATE 'DELETE FROM pedidos ...
SELECT s.name, s.type, s.line, TRIM(s.text) AS texto
  FROM user_source s
 WHERE UPPER(s.text) LIKE '%PEDIDOS%'
   AND NOT EXISTS (SELECT 1
                     FROM user_dependencies d
                    WHERE d.name = s.name
                      AND d.type = s.type
                      AND d.referenced_name = 'PEDIDOS')
 ORDER BY s.name, s.line;

-- Com limite de palavra: PEDIDOS não pode estar colado a letra, dígito, _, $ ou #.
-- Esperado: só TMP_PROC_LIMPEZA
SELECT s.name, s.type, s.line, TRIM(s.text) AS texto
  FROM user_source s
 WHERE REGEXP_LIKE(s.text, '(^|[^A-Z0-9_$#])PEDIDOS([^A-Z0-9_$#]|$)', 'i')
   AND NOT EXISTS (SELECT 1
                     FROM user_dependencies d
                    WHERE d.name = s.name
                      AND d.type = s.type
                      AND d.referenced_name = 'PEDIDOS')
 ORDER BY s.name, s.line;

-- O texto de views fica em USER_VIEWS (LONG), não em USER_SOURCE.

-- 5. Análise de impacto combinada: dependência registrada + texto do código + jobs.
-- Esperado:
--   dependência     TMP_VW_PEDIDOS_VALOR   VIEW
--   texto do código TMP_PROC_LIMPEZA       PROCEDURE
--   (nenhum job, a menos que você tenha criado algum)
SELECT 'dependência' AS fonte, name, type
  FROM user_dependencies
 WHERE referenced_name = 'PEDIDOS' AND referenced_owner = USER
UNION
SELECT 'texto do código', name, type
  FROM user_source
 WHERE REGEXP_LIKE(text, '(^|[^A-Z0-9_$#])PEDIDOS([^A-Z0-9_$#]|$)', 'i')
   AND name NOT IN (SELECT name FROM user_dependencies WHERE referenced_name = 'PEDIDOS')
UNION
SELECT 'job', job_name, 'JOB'
  FROM user_scheduler_jobs
 WHERE REGEXP_LIKE(job_action, '(^|[^A-Z0-9_$#])PEDIDOS([^A-Z0-9_$#]|$)', 'i')
 ORDER BY 1, 2;

-- 6. Outros schemas que usam suas tabelas (precisa de DBA_ para ver tudo).
-- Esperado: nenhuma linha no ambiente de estudo
SELECT owner, name, type, referenced_name
  FROM all_dependencies
 WHERE referenced_owner = USER
   AND owner <> USER
 ORDER BY owner, name;

DROP PROCEDURE tmp_proc_limpeza;
DROP PACKAGE tmp_pkg_relatorio;
DROP FUNCTION tmp_fn_total_cliente;
DROP VIEW tmp_vw_pedidos_valor;
