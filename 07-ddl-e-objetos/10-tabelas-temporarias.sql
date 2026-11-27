-- =============================================================================
-- Tópico : Tabelas temporárias — GTT e private temporary table
-- Seção  : 07-ddl-e-objetos
-- Versão : 19c (private temporary table desde o 18c)
-- Requer : schema de exemplo (00-ambiente); usuário com CREATE TABLE.
--          O passo 3 precisa de uma segunda sessão.
-- =============================================================================

-- 1. GTT com ON COMMIT DELETE ROWS: dados somem no COMMIT.
CREATE GLOBAL TEMPORARY TABLE tmp_gtt_transacao (
    id_produto NUMBER,
    valor      NUMBER
) ON COMMIT DELETE ROWS;

INSERT INTO tmp_gtt_transacao
SELECT id_produto, SUM(quantidade * preco_unitario) FROM itens_pedido GROUP BY id_produto;

-- Esperado: 14 (produtos vendidos)
SELECT COUNT(*) FROM tmp_gtt_transacao;

COMMIT;

-- Esperado: 0
SELECT COUNT(*) FROM tmp_gtt_transacao;

-- 2. GTT com ON COMMIT PRESERVE ROWS: dados ficam até o fim da sessão.
CREATE GLOBAL TEMPORARY TABLE tmp_gtt_sessao (
    id_cliente NUMBER,
    total      NUMBER
) ON COMMIT PRESERVE ROWS;

INSERT INTO tmp_gtt_sessao
SELECT p.id_cliente, SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2))
  FROM pedidos p JOIN itens_pedido i ON i.id_pedido = p.id_pedido
 WHERE p.status <> 'CANCELADO'
 GROUP BY p.id_cliente;
COMMIT;

-- Esperado: 10 (continuam depois do COMMIT)
SELECT COUNT(*) FROM tmp_gtt_sessao;

-- Usada em join como qualquer tabela.
SELECT c.nome, g.total
  FROM tmp_gtt_sessao g
  JOIN clientes       c ON c.id_cliente = g.id_cliente
 ORDER BY g.total DESC
 FETCH FIRST 3 ROWS ONLY;

-- 3. Em OUTRA sessão (mesmo usuário), a GTT existe, mas está vazia.
--    Rode na segunda sessão:
--      SELECT COUNT(*) FROM tmp_gtt_sessao;
--    Esperado lá: 0

-- 4. GTT com dados na sessão não pode ser apagada.
-- Esperado: ORA-14452 (tentativa de criar, alterar ou eliminar um índice em uma tabela temporária já em uso)
DROP TABLE tmp_gtt_sessao;

-- Esvaziar a sessão antes.
TRUNCATE TABLE tmp_gtt_sessao;
DROP TABLE tmp_gtt_sessao;
DROP TABLE tmp_gtt_transacao;

-- 5. Private temporary table [18c+]: estrutura e dados só da sessão.
--    Criá-la NÃO faz commit: o UPDATE abaixo continua pendente.
UPDATE produtos SET preco_unitario = preco_unitario WHERE id_produto = 1;

CREATE PRIVATE TEMPORARY TABLE ora$ptt_resumo (
    id_categoria NUMBER,
    produtos     NUMBER
) ON COMMIT DROP DEFINITION;

INSERT INTO ora$ptt_resumo SELECT id_categoria, COUNT(*) FROM produtos GROUP BY id_categoria;

-- Esperado: 5 categorias com produtos
SELECT * FROM ora$ptt_resumo ORDER BY id_categoria;

-- A transação continua aberta (prova de que o CREATE não fez commit).
-- Esperado: um identificador de transação
SELECT DBMS_TRANSACTION.LOCAL_TRANSACTION_ID AS transacao FROM dual;

-- No ROLLBACK (ou COMMIT), a tabela some.
ROLLBACK;

-- Esperado: ORA-00942 (tabela ou view não existe)
SELECT * FROM ora$ptt_resumo;

-- 6. Nome fora do prefixo: recusado.
-- Esperado: erro de nome inválido (o nome precisa começar com o prefixo ORA$PTT_)
CREATE PRIVATE TEMPORARY TABLE tmp_sem_prefixo (x NUMBER);

-- Prefixo configurado no banco.
SELECT value AS prefixo FROM v$parameter WHERE name = 'private_temp_table_prefix';
