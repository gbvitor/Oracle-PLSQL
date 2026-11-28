-- =============================================================================
-- Projeto : 01 — Controle de estoque — views de consulta
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : 01-tabelas.sql; CREATE VIEW
-- =============================================================================

-- Kardex: cada movimento com o saldo depois dele, por produto e depósito.
CREATE OR REPLACE VIEW est_vw_kardex AS
SELECT m.id_produto,
       p.codigo,
       m.id_deposito,
       m.data_movimento,
       m.id_movimento,
       m.tipo,
       m.documento,
       m.sinal * m.quantidade AS quantidade,
       SUM(m.sinal * m.quantidade) OVER (PARTITION BY m.id_produto, m.id_deposito
                                         ORDER BY m.data_movimento, m.id_movimento) AS saldo
  FROM est_movimentos m
  JOIN est_produtos p ON p.id_produto = m.id_produto;

-- Produtos ativos com saldo total (todos os depósitos) abaixo do mínimo.
CREATE OR REPLACE VIEW est_vw_abaixo_minimo AS
SELECT p.id_produto,
       p.codigo,
       p.descricao,
       p.estoque_minimo,
       NVL(SUM(s.quantidade), 0) AS saldo
  FROM est_produtos p
  LEFT JOIN est_saldos s ON s.id_produto = p.id_produto
 WHERE p.ativo = 'S'
 GROUP BY p.id_produto, p.codigo, p.descricao, p.estoque_minimo
HAVING NVL(SUM(s.quantidade), 0) < p.estoque_minimo;
