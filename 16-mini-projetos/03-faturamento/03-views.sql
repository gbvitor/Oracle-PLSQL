-- =============================================================================
-- Projeto : 03 — Faturamento simplificado — views de consulta
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : 01-tabelas.sql, 02-pacote.sql; CREATE VIEW
-- =============================================================================

-- Limite, em aberto e disponível por cliente.
CREATE OR REPLACE VIEW fat_vw_posicao_cliente AS
SELECT c.id_cliente,
       c.nome,
       c.limite_credito,
       NVL(a.em_aberto, 0)                       AS em_aberto,
       c.limite_credito - NVL(a.em_aberto, 0)    AS disponivel
  FROM fat_clientes c
  LEFT JOIN (SELECT n.id_cliente, SUM(t.valor - t.valor_pago) AS em_aberto
               FROM fat_titulos t
               JOIN fat_notas n ON n.id_nota = t.id_nota
              WHERE t.situacao = 'ABERTO'
              GROUP BY n.id_cliente) a
    ON a.id_cliente = c.id_cliente;

-- Títulos em aberto com saldo, atraso e encargos calculados para hoje.
-- Usa a data do servidor: o resultado muda a cada dia (os testes não usam esta view).
CREATE OR REPLACE VIEW fat_vw_titulos_abertos AS
SELECT t.id_titulo,
       n.serie,
       n.numero,
       t.parcela,
       n.id_cliente,
       t.vencimento,
       t.valor,
       t.valor_pago,
       t.valor - t.valor_pago                                        AS saldo,
       GREATEST(TRUNC(SYSDATE) - t.vencimento, 0)                    AS dias_atraso,
       fat_pkg_faturamento.encargos(t.valor - t.valor_pago, t.vencimento, SYSDATE) AS encargos_hoje
  FROM fat_titulos t
  JOIN fat_notas n ON n.id_nota = t.id_nota
 WHERE t.situacao = 'ABERTO';
