-- =============================================================================
-- Tópico : Constraints e chaves — tipos, PKs, mapa de FKs, quem referencia,
--          FK sem índice, CHECKs, situação
-- Seção  : 10-dicionario-de-dados
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente), recém-instalado
-- =============================================================================

COLUMN constraint_name FORMAT A26
COLUMN table_name      FORMAT A14
COLUMN colunas         FORMAT A24
COLUMN filha           FORMAT A30
COLUMN pai             FORMAT A30
COLUMN regra           FORMAT A60 WORD_WRAPPED

-- 1. Quantas constraints de cada tipo.
-- Esperado: C 37 (28 de NOT NULL com nome gerado + 9 CHECK nomeadas) | P 7 | R 8 | U 3
SELECT constraint_type,
       COUNT(*) AS total,
       SUM(CASE WHEN generated = 'GENERATED NAME' THEN 1 ELSE 0 END) AS nome_gerado
  FROM user_constraints
 WHERE table_name IN (SELECT table_name FROM user_tables)
 GROUP BY constraint_type
 ORDER BY constraint_type;

-- 2. Chave primária de cada tabela, com as colunas na ordem.
-- Esperado: ITENS_PEDIDO tem PK composta (ID_PEDIDO, NR_ITEM); as demais, uma coluna
SELECT c.table_name,
       c.constraint_name,
       LISTAGG(cc.column_name, ', ') WITHIN GROUP (ORDER BY cc.position) AS colunas
  FROM user_constraints c
  JOIN user_cons_columns cc ON cc.constraint_name = c.constraint_name
 WHERE c.constraint_type = 'P'
 GROUP BY c.table_name, c.constraint_name
 ORDER BY c.table_name;

-- Tabelas sem chave primária.
-- Esperado: nenhuma linha
SELECT table_name
  FROM user_tables t
 WHERE NOT EXISTS (SELECT 1 FROM user_constraints c
                    WHERE c.table_name = t.table_name AND c.constraint_type = 'P')
 ORDER BY table_name;

-- 3. Mapa de FKs: coluna filha -> coluna pai, ligando por POSITION.
-- Esperado:
--   CATEGORIAS.ID_CATEGORIA_PAI    -> CATEGORIAS.ID_CATEGORIA        NO ACTION
--   FUNCIONARIOS.ID_DEPARTAMENTO   -> DEPARTAMENTOS.ID_DEPARTAMENTO  NO ACTION
--   FUNCIONARIOS.ID_GERENTE        -> FUNCIONARIOS.ID_FUNCIONARIO    NO ACTION
--   ITENS_PEDIDO.ID_PEDIDO         -> PEDIDOS.ID_PEDIDO              CASCADE
--   ITENS_PEDIDO.ID_PRODUTO        -> PRODUTOS.ID_PRODUTO            NO ACTION
--   PEDIDOS.ID_CLIENTE             -> CLIENTES.ID_CLIENTE            NO ACTION
--   PEDIDOS.ID_VENDEDOR            -> FUNCIONARIOS.ID_FUNCIONARIO    NO ACTION
--   PRODUTOS.ID_CATEGORIA          -> CATEGORIAS.ID_CATEGORIA        NO ACTION
SELECT fc.table_name || '.' || fc.column_name AS filha,
       pc.table_name || '.' || pc.column_name AS pai,
       f.delete_rule,
       f.constraint_name
  FROM user_constraints f
  JOIN user_constraints p   ON p.constraint_name  = f.r_constraint_name
  JOIN user_cons_columns fc ON fc.constraint_name = f.constraint_name
  JOIN user_cons_columns pc ON pc.constraint_name = p.constraint_name
                           AND pc.position        = fc.position
 WHERE f.constraint_type = 'R'
 ORDER BY filha;

-- 4. Quem referencia esta tabela? (antes de excluir ou alterar a chave)
-- Esperado: FUNCIONARIOS (ID_GERENTE, a própria tabela) | PEDIDOS (ID_VENDEDOR)
SELECT f.table_name AS tabela_filha,
       fc.column_name,
       f.constraint_name,
       f.delete_rule
  FROM user_constraints f
  JOIN user_constraints p   ON p.constraint_name  = f.r_constraint_name
  JOIN user_cons_columns fc ON fc.constraint_name = f.constraint_name
 WHERE f.constraint_type = 'R'
   AND p.table_name = 'FUNCIONARIOS'
 ORDER BY f.table_name, fc.column_name;

-- 5. FK sem índice na coluna filha.
-- Esperado: nenhuma linha (o schema de exemplo cria os índices; ITENS_PEDIDO.ID_PEDIDO
--           é coberto pela primeira coluna da PK)
SELECT c.table_name,
       c.constraint_name,
       LISTAGG(cc.column_name, ', ') WITHIN GROUP (ORDER BY cc.position) AS colunas
  FROM user_constraints c
  JOIN user_cons_columns cc ON cc.constraint_name = c.constraint_name
 WHERE c.constraint_type = 'R'
   AND NOT EXISTS (SELECT 1
                     FROM user_ind_columns ic
                    WHERE ic.table_name      = cc.table_name
                      AND ic.column_name     = cc.column_name
                      AND ic.column_position = cc.position)
 GROUP BY c.table_name, c.constraint_name
 ORDER BY c.table_name;

-- Provocar o caso: tabela filha com FK e sem índice.
CREATE TABLE tmp_ocorrencias (
    id_ocorrencia NUMBER CONSTRAINT pk_tmp_ocorrencias PRIMARY KEY,
    id_cliente    NUMBER(6) CONSTRAINT fk_tmp_ocorrencias_cliente REFERENCES clientes (id_cliente),
    texto         VARCHAR2(200)
);

-- Esperado: TMP_OCORRENCIAS | FK_TMP_OCORRENCIAS_CLIENTE | ID_CLIENTE
--           (repita a consulta acima)
SELECT c.table_name,
       c.constraint_name,
       LISTAGG(cc.column_name, ', ') WITHIN GROUP (ORDER BY cc.position) AS colunas
  FROM user_constraints c
  JOIN user_cons_columns cc ON cc.constraint_name = c.constraint_name
 WHERE c.constraint_type = 'R'
   AND NOT EXISTS (SELECT 1
                     FROM user_ind_columns ic
                    WHERE ic.table_name      = cc.table_name
                      AND ic.column_name     = cc.column_name
                      AND ic.column_position = cc.position)
 GROUP BY c.table_name, c.constraint_name
 ORDER BY c.table_name;

DROP TABLE tmp_ocorrencias PURGE;

-- 6. Regras de negócio declaradas (CHECK com nome dado).
-- Esperado: 9 linhas, por exemplo
--   CK_CLIENTES_TIPO        tipo_pessoa IN ('F', 'J')
--   CK_ITENS_PEDIDO_DESCONTO pct_desconto BETWEEN 0 AND 100
--   CK_PEDIDOS_STATUS       status IN ('ABERTO', 'FATURADO', 'ENTREGUE', 'CANCELADO')
SELECT table_name, constraint_name, search_condition AS regra
  FROM user_constraints
 WHERE constraint_type = 'C'
   AND generated = 'USER NAME'
 ORDER BY table_name, constraint_name;

-- 7. Constraints desabilitadas ou não validadas.
-- Esperado: nenhuma linha
SELECT table_name, constraint_name, constraint_type, status, validated
  FROM user_constraints
 WHERE status <> 'ENABLED' OR validated <> 'VALIDATED'
 ORDER BY table_name;

-- 8. Índice que sustenta cada PK e UK.
-- Esperado: 10 linhas; índice com o mesmo nome da constraint (PK_CLIENTES, UK_CLIENTES_DOCUMENTO...)
SELECT table_name, constraint_name, constraint_type, index_name
  FROM user_constraints
 WHERE constraint_type IN ('P', 'U')
 ORDER BY table_name, constraint_type;

-- 9. DDL de uma constraint (DBMS_METADATA: ver seção 07, tópico 12).
SET LONG 10000
SELECT DBMS_METADATA.GET_DDL('REF_CONSTRAINT', 'FK_ITENS_PEDIDO_PEDIDO') AS ddl FROM dual;
-- Esperado: ALTER TABLE "ESTUDO"."ITENS_PEDIDO" ADD CONSTRAINT "FK_ITENS_PEDIDO_PEDIDO"
--           FOREIGN KEY ("ID_PEDIDO") REFERENCES "ESTUDO"."PEDIDOS" ("ID_PEDIDO") ON DELETE CASCADE ENABLE
