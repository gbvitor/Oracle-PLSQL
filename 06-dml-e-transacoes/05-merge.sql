-- =============================================================================
-- Tópico : MERGE
-- Seção  : 06-dml-e-transacoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); usuário com CREATE TABLE
-- Trabalha numa cópia de produtos; nada muda no schema de exemplo.
-- =============================================================================

CREATE TABLE tmp_produtos AS SELECT * FROM produtos;
ALTER TABLE tmp_produtos ADD CONSTRAINT pk_tmp_produtos PRIMARY KEY (id_produto);

-- Arquivo de preços recebido do fornecedor (origem).
--   1 e 2: preço novo | 3: mesmo preço | 15: inativo, vai ser descontinuado
--   16 e 17: produtos novos
CREATE TABLE tmp_precos_fornecedor (
    id_produto  NUMBER,
    nome        VARCHAR2(100),
    preco       NUMBER(10,2),
    situacao    VARCHAR2(12)
);
INSERT INTO tmp_precos_fornecedor VALUES ( 1, 'Mouse optico USB',     42.90,  'ATIVO');
INSERT INTO tmp_precos_fornecedor VALUES ( 2, 'Teclado ABNT2',        94.90,  'ATIVO');
INSERT INTO tmp_precos_fornecedor VALUES ( 3, 'Monitor 24 polegadas', 899.00, 'ATIVO');
INSERT INTO tmp_precos_fornecedor VALUES (15, 'Hub USB 4 portas',     79.90,  'DESCONTINUADO');
INSERT INTO tmp_precos_fornecedor VALUES (16, 'Mousepad',             19.90,  'ATIVO');
INSERT INTO tmp_precos_fornecedor VALUES (17, 'Suporte de monitor',  149.00,  'ATIVO');
COMMIT;

-- 1. MERGE completo: atualiza existentes, insere novos.
-- Esperado: 6 linhas mescladas (4 atualizadas, 2 inseridas)
MERGE INTO tmp_produtos d
USING tmp_precos_fornecedor o
   ON (d.id_produto = o.id_produto)
 WHEN MATCHED THEN
      UPDATE SET d.preco_unitario = o.preco
 WHEN NOT MATCHED THEN
      INSERT (id_produto, nome, id_categoria, unidade, preco_unitario, ativo)
      VALUES (o.id_produto, o.nome, 2, 'UN', o.preco, 'S');

-- Esperado: 1 42.9 | 2 94.9 | 3 899 | 15 79.9 | 16 19.9 | 17 149
SELECT id_produto, nome, preco_unitario
  FROM tmp_produtos
 WHERE id_produto IN (1, 2, 3, 15, 16, 17)
 ORDER BY id_produto;

ROLLBACK;

-- 2. Atualizando só o que mudou: os produtos 3 e 15 têm o mesmo preço da
--    origem e ficam de fora.
-- Esperado: 4 linhas mescladas (2 atualizadas: 1 e 2; 2 inseridas: 16 e 17)
MERGE INTO tmp_produtos d
USING tmp_precos_fornecedor o
   ON (d.id_produto = o.id_produto)
 WHEN MATCHED THEN
      UPDATE SET d.preco_unitario = o.preco
       WHERE DECODE(d.preco_unitario, o.preco, 0, 1) = 1
 WHEN NOT MATCHED THEN
      INSERT (id_produto, nome, id_categoria, unidade, preco_unitario, ativo)
      VALUES (o.id_produto, o.nome, 2, 'UN', o.preco, 'S');

ROLLBACK;

-- 3. DELETE WHERE: apagar o que o fornecedor descontinuou.
--    O DELETE só age sobre linhas atualizadas pelo MERGE, e usa os valores
--    depois do UPDATE. Aqui o UPDATE também marca o produto como inativo.
-- Esperado: produto 15 apagado; 16 e 17 inseridos
MERGE INTO tmp_produtos d
USING tmp_precos_fornecedor o
   ON (d.id_produto = o.id_produto)
 WHEN MATCHED THEN
      UPDATE SET d.preco_unitario = o.preco,
                 d.ativo          = CASE o.situacao WHEN 'DESCONTINUADO' THEN 'N' ELSE 'S' END
      DELETE WHERE d.ativo = 'N'
 WHEN NOT MATCHED THEN
      INSERT (id_produto, nome, id_categoria, unidade, preco_unitario, ativo)
      VALUES (o.id_produto, o.nome, 2, 'UN', o.preco, 'S');

-- Esperado: 16 linhas (15 - 1 + 2)
SELECT COUNT(*) FROM tmp_produtos;

ROLLBACK;

-- 4. Só WHEN MATCHED: UPDATE a partir de outra tabela.
-- Esperado: 4 linhas mescladas
MERGE INTO tmp_produtos d
USING tmp_precos_fornecedor o
   ON (d.id_produto = o.id_produto)
 WHEN MATCHED THEN
      UPDATE SET d.preco_unitario = o.preco;

ROLLBACK;

-- 5. Origem com duas linhas para o mesmo destino: erro.
INSERT INTO tmp_precos_fornecedor VALUES (1, 'Mouse optico USB', 44.90, 'ATIVO');

-- Esperado: ORA-30926 (não foi possível obter um conjunto estável de linhas nas tabelas de origem)
MERGE INTO tmp_produtos d
USING tmp_precos_fornecedor o
   ON (d.id_produto = o.id_produto)
 WHEN MATCHED THEN
      UPDATE SET d.preco_unitario = o.preco;

-- Correção: deduplicar a origem antes (aqui, o maior preço de cada produto).
-- Esperado: 4 linhas mescladas; produto 1 com 44.9
MERGE INTO tmp_produtos d
USING (SELECT id_produto, MAX(preco) AS preco
         FROM tmp_precos_fornecedor
        GROUP BY id_produto) o
   ON (d.id_produto = o.id_produto)
 WHEN MATCHED THEN
      UPDATE SET d.preco_unitario = o.preco;

ROLLBACK;

-- 6. Coluna do ON não pode ser atualizada.
-- Esperado: ORA-38104 (as colunas referenciadas na cláusula ON não podem ser atualizadas)
MERGE INTO tmp_produtos d
USING tmp_precos_fornecedor o
   ON (d.id_produto = o.id_produto)
 WHEN MATCHED THEN
      UPDATE SET d.id_produto = o.id_produto + 100;

-- Limpeza
DROP TABLE tmp_precos_fornecedor PURGE;
DROP TABLE tmp_produtos PURGE;
