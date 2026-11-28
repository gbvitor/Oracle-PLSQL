-- =============================================================================
-- Tópico : Roteiro de descoberta de um schema desconhecido
-- Seção  : 10-dicionario-de-dados
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente), recém-instalado e com estatísticas
--          coletadas (tópico 02, passo 1). DBA_SEGMENTS no passo 2 exige
--          SELECT ANY DICTIONARY ou SELECT_CATALOG_ROLE.
--
-- O schema analisado vem da variável :dono. Por padrão, o próprio usuário;
-- para outro schema, troque a linha do EXEC (o nome vai em maiúsculas).
-- Os valores esperados são os do schema de exemplo.
-- =============================================================================

VARIABLE dono VARCHAR2(128)
EXEC :dono := USER

COLUMN tabela      FORMAT A14
COLUMN object_type FORMAT A14
COLUMN pk          FORMAT A20
COLUMN filha       FORMAT A30
COLUMN pai         FORMAT A30
COLUMN comentario  FORMAT A40 TRUNCATED

-- 1. O que existe, e quanto.
-- Esperado: INDEX 18 | TABLE 7
SELECT object_type, COUNT(*) AS objetos
  FROM all_objects
 WHERE owner = :dono
   AND object_name NOT LIKE 'BIN$%'
 GROUP BY object_type
 ORDER BY objetos DESC, object_type;

-- 2. Tabelas por volume (estatística) e por espaço ocupado.
-- Esperado: ITENS_PEDIDO 54 | PEDIDOS 24 | PRODUTOS 15 | FUNCIONARIOS 14 |
--           CLIENTES 12 | CATEGORIAS 7 | DEPARTAMENTOS 5
SELECT t.table_name AS tabela,
       t.num_rows,
       t.last_analyzed,
       (SELECT SUM(s.bytes) / 1024
          FROM dba_segments s
         WHERE s.owner = t.owner
           AND s.segment_name = t.table_name) AS kb_tabela
  FROM all_tables t
 WHERE t.owner = :dono
 ORDER BY t.num_rows DESC NULLS LAST, t.table_name;

-- 3. Tabelas sem chave primária.
-- Esperado: nenhuma linha
SELECT t.table_name AS tabela
  FROM all_tables t
 WHERE t.owner = :dono
   AND NOT EXISTS (SELECT 1
                     FROM all_constraints c
                    WHERE c.owner = t.owner
                      AND c.table_name = t.table_name
                      AND c.constraint_type = 'P')
 ORDER BY 1;

-- 4. Mapa de FKs.
-- Esperado: as 8 ligações do tópico 03
SELECT fc.table_name || '.' || fc.column_name AS filha,
       pc.table_name || '.' || pc.column_name AS pai,
       f.delete_rule
  FROM all_constraints f
  JOIN all_constraints p    ON p.owner = f.r_owner AND p.constraint_name = f.r_constraint_name
  JOIN all_cons_columns fc  ON fc.owner = f.owner AND fc.constraint_name = f.constraint_name
  JOIN all_cons_columns pc  ON pc.owner = p.owner AND pc.constraint_name = p.constraint_name
                           AND pc.position = fc.position
 WHERE f.owner = :dono
   AND f.constraint_type = 'R'
 ORDER BY filha;

-- 5. Ordem de carga: nível 1 não depende de ninguém; cada nível depende só dos anteriores.
--    Auto-relacionamento (categoria pai, gerente) é ignorado. Para excluir, a ordem inversa.
-- Esperado:
--   1 CATEGORIAS, CLIENTES, DEPARTAMENTOS
--   2 FUNCIONARIOS, PRODUTOS
--   3 PEDIDOS
--   4 ITENS_PEDIDO
WITH fk AS (
    SELECT DISTINCT f.table_name AS filha, p.table_name AS pai
      FROM all_constraints f
      JOIN all_constraints p ON p.owner = f.r_owner AND p.constraint_name = f.r_constraint_name
     WHERE f.owner = :dono
       AND f.constraint_type = 'R'
       AND f.table_name <> p.table_name
),
niveis (tabela, nivel) AS (
    SELECT t.table_name, 1
      FROM all_tables t
     WHERE t.owner = :dono
       AND NOT EXISTS (SELECT 1 FROM fk WHERE fk.filha = t.table_name)
    UNION ALL
    SELECT fk.filha, n.nivel + 1
      FROM fk
      JOIN niveis n ON n.tabela = fk.pai
     WHERE n.nivel < 50
)
CYCLE tabela SET em_ciclo TO 'S' DEFAULT 'N'
SELECT nivel, LISTAGG(tabela, ', ') WITHIN GROUP (ORDER BY tabela) AS tabelas
  FROM (SELECT tabela, MAX(nivel) AS nivel FROM niveis GROUP BY tabela)
 GROUP BY nivel
 ORDER BY nivel;

-- 6. Ligações não declaradas: colunas com cara de chave fora de PK e FK.
-- Esperado: nenhuma linha (no schema de exemplo toda coluna ID_ é PK ou FK).
--           Num sistema sem FKs declaradas, esta é a lista de candidatas a conferir.
SELECT c.table_name AS tabela, c.column_name
  FROM all_tab_columns c
  JOIN all_tables t ON t.owner = c.owner AND t.table_name = c.table_name
 WHERE c.owner = :dono
   AND REGEXP_LIKE(c.column_name, '^(ID|CD|COD|NU|NR)_|_(ID|COD)$')
   AND NOT EXISTS (SELECT 1
                     FROM all_cons_columns cc
                     JOIN all_constraints k ON k.owner = cc.owner AND k.constraint_name = cc.constraint_name
                    WHERE cc.owner = c.owner
                      AND cc.table_name = c.table_name
                      AND cc.column_name = c.column_name
                      AND k.constraint_type IN ('P', 'R'))
 ORDER BY 1, 2;

-- 7. FKs sem índice.
-- Esperado: nenhuma linha
SELECT c.table_name AS tabela,
       c.constraint_name,
       LISTAGG(cc.column_name, ', ') WITHIN GROUP (ORDER BY cc.position) AS colunas
  FROM all_constraints c
  JOIN all_cons_columns cc ON cc.owner = c.owner AND cc.constraint_name = c.constraint_name
 WHERE c.owner = :dono
   AND c.constraint_type = 'R'
   AND NOT EXISTS (SELECT 1
                     FROM all_ind_columns ic
                    WHERE ic.table_owner     = cc.owner
                      AND ic.table_name      = cc.table_name
                      AND ic.column_name     = cc.column_name
                      AND ic.column_position = cc.position)
 GROUP BY c.table_name, c.constraint_name
 ORDER BY 1;

-- 8. Código e triggers: o que pode mexer nos dados sem aparecer na consulta.
-- Esperado: nenhuma linha em cada consulta (schema de exemplo só tem tabelas e índices)
SELECT object_type, object_name, status
  FROM all_objects
 WHERE owner = :dono
   AND object_type IN ('PROCEDURE', 'FUNCTION', 'PACKAGE', 'PACKAGE BODY', 'TRIGGER', 'TYPE', 'VIEW')
 ORDER BY object_type, object_name;

SELECT table_name AS tabela, trigger_name, trigger_type, triggering_event, status
  FROM all_triggers
 WHERE owner = :dono
 ORDER BY table_name, trigger_name;

SELECT owner, job_name, enabled, repeat_interval
  FROM all_scheduler_jobs
 WHERE owner = :dono;

-- 9. Documentação existente.
-- Esperado: 7 tabelas comentadas; colunas comentadas 6 de 43
SELECT (SELECT COUNT(*) FROM all_tab_comments
         WHERE owner = :dono AND table_type = 'TABLE' AND comments IS NOT NULL) AS tabelas_comentadas,
       (SELECT COUNT(*) FROM all_col_comments cc
          JOIN all_tables t ON t.owner = cc.owner AND t.table_name = cc.table_name
         WHERE cc.owner = :dono AND cc.comments IS NOT NULL) AS colunas_comentadas,
       (SELECT COUNT(*) FROM all_tab_columns c
          JOIN all_tables t ON t.owner = c.owner AND t.table_name = c.table_name
         WHERE c.owner = :dono) AS colunas
  FROM dual;

-- 10. Ficha de cada tabela, numa linha.
-- Esperado:
--   TABELA         COLS PK                  FK_SAI FK_ENTRA INDICES LINHAS
--   CATEGORIAS        3 ID_CATEGORIA             1        2       2      7
--   CLIENTES         10 ID_CLIENTE               0        1       2     12
--   DEPARTAMENTOS     3 ID_DEPARTAMENTO          0        1       2      5
--   FUNCIONARIOS      9 ID_FUNCIONARIO           2        2       4     14
--   ITENS_PEDIDO      6 ID_PEDIDO, NR_ITEM       2        0       2     54
--   PEDIDOS           6 ID_PEDIDO                2        1       4     24
--   PRODUTOS          6 ID_PRODUTO               1        1       2     15
--   (FK_SAI: FKs desta tabela para outras; FK_ENTRA: FKs de outras tabelas, ou dela
--    mesma, apontando para esta. Auto-relacionamento conta nos dois lados.)
SELECT t.table_name AS tabela,
       (SELECT COUNT(*) FROM all_tab_columns c
         WHERE c.owner = t.owner AND c.table_name = t.table_name) AS cols,
       (SELECT LISTAGG(cc.column_name, ', ') WITHIN GROUP (ORDER BY cc.position)
          FROM all_constraints k
          JOIN all_cons_columns cc ON cc.owner = k.owner AND cc.constraint_name = k.constraint_name
         WHERE k.owner = t.owner AND k.table_name = t.table_name AND k.constraint_type = 'P') AS pk,
       (SELECT COUNT(*) FROM all_constraints f
         WHERE f.owner = t.owner AND f.table_name = t.table_name AND f.constraint_type = 'R') AS fk_sai,
       (SELECT COUNT(*) FROM all_constraints f
          JOIN all_constraints p ON p.owner = f.r_owner AND p.constraint_name = f.r_constraint_name
         WHERE f.constraint_type = 'R' AND p.owner = t.owner AND p.table_name = t.table_name) AS fk_entra,
       (SELECT COUNT(*) FROM all_indexes i
         WHERE i.table_owner = t.owner AND i.table_name = t.table_name) AS indices,
       t.num_rows AS linhas,
       (SELECT tc.comments FROM all_tab_comments tc
         WHERE tc.owner = t.owner AND tc.table_name = t.table_name) AS comentario
  FROM all_tables t
 WHERE t.owner = :dono
 ORDER BY t.table_name;
