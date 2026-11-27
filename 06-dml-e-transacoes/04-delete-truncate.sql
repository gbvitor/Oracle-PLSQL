-- =============================================================================
-- Tópico : DELETE e TRUNCATE
-- Seção  : 06-dml-e-transacoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); usuário com CREATE TABLE
-- =============================================================================

-- 1. DELETE com WHERE e com subquery; ROLLBACK desfaz.
-- Esperado: 1 linha apagada
DELETE FROM itens_pedido
 WHERE id_pedido IN (SELECT id_pedido FROM pedidos WHERE status = 'CANCELADO');

-- Esperado: 53
SELECT COUNT(*) FROM itens_pedido;

ROLLBACK;

-- Esperado: 54
SELECT COUNT(*) FROM itens_pedido;

-- 2. DELETE com EXISTS: itens de pedidos de clientes inativos (nenhum).
-- Esperado: 0 linhas apagadas
DELETE FROM itens_pedido i
 WHERE EXISTS (SELECT 1
                 FROM pedidos  p
                 JOIN clientes c ON c.id_cliente = p.id_cliente
                WHERE p.id_pedido = i.id_pedido
                  AND c.ativo     = 'N');

-- 3. DELETE em tabela pai com filhos: a FK impede.
-- Esperado: ORA-02292 (registro filho localizado)
DELETE FROM produtos WHERE id_produto = 8;

-- Produto sem venda pode ser apagado.
-- Esperado: 1 linha apagada
DELETE FROM produtos WHERE id_produto = 15;

ROLLBACK;

-- 4. TRUNCATE não tem rollback.
CREATE TABLE tmp_carga AS SELECT * FROM itens_pedido;

-- Esperado: 54
SELECT COUNT(*) FROM tmp_carga;

TRUNCATE TABLE tmp_carga;
ROLLBACK;

-- Esperado: 0
SELECT COUNT(*) FROM tmp_carga;

-- 5. TRUNCATE confirma o que estava pendente na transação.
INSERT INTO tmp_carga SELECT * FROM itens_pedido WHERE id_pedido = 1001;

-- Este UPDATE no schema de exemplo ficaria pendente...
UPDATE produtos SET ativo = ativo WHERE id_produto = 1;

-- ...e o TRUNCATE de outra tabela o confirma.
TRUNCATE TABLE tmp_carga;
ROLLBACK;

-- Não há como desfazer o UPDATE acima: ele foi confirmado pelo TRUNCATE.
-- (Aqui foi inofensivo porque o valor não mudou.)

-- 6. TRUNCATE em tabela referenciada por FK: recusado mesmo com a filha vazia.
CREATE TABLE tmp_pai   (id NUMBER PRIMARY KEY);
CREATE TABLE tmp_filha (id NUMBER, id_pai NUMBER REFERENCES tmp_pai (id));
INSERT INTO tmp_pai VALUES (1);
COMMIT;

-- Esperado: ORA-02266 (chaves exclusivas/primárias na tabela referenciadas por chaves externas ativadas)
TRUNCATE TABLE tmp_pai;

-- DELETE funciona (a filha não tem linhas).
-- Esperado: 1 linha apagada
DELETE FROM tmp_pai;
ROLLBACK;

-- 7. Flashback Query não atravessa TRUNCATE.
--    Usa COLUMN ... NEW_VALUE e variável de substituição do SQL*Plus/SQLcl.
--    A filha sai antes, para o TRUNCATE da mãe ser aceito.
DROP TABLE tmp_filha PURGE;

COLUMN scn_antes NEW_VALUE scn_antes
SELECT current_scn AS scn_antes FROM v$database;

TRUNCATE TABLE tmp_pai;

-- Esperado: ORA-01466 (não é possível ler os dados - a definição da tabela foi alterada)
SELECT * FROM tmp_pai AS OF SCN &scn_antes;

-- Limpeza
DROP TABLE tmp_pai PURGE;
DROP TABLE tmp_carga PURGE;
