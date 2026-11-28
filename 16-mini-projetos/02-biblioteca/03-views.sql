-- =============================================================================
-- Projeto : 02 — Biblioteca — views de consulta
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : 01-tabelas.sql, 02-pacote.sql; CREATE VIEW
-- =============================================================================

-- Empréstimos em atraso hoje, com a multa que seria cobrada se devolvessem hoje.
-- Usa a data do servidor: o resultado muda a cada dia (os testes não usam esta view).
CREATE OR REPLACE VIEW bib_vw_atrasos AS
SELECT e.id_emprestimo,
       l.id_leitor,
       l.nome           AS leitor,
       x.id_exemplar,
       o.titulo,
       e.data_prevista,
       TRUNC(SYSDATE) - e.data_prevista                 AS dias_atraso,
       (TRUNC(SYSDATE) - e.data_prevista) * c.multa_dia AS multa_ate_hoje
  FROM bib_emprestimos e
  JOIN bib_leitores l          ON l.id_leitor = e.id_leitor
  JOIN bib_categorias_leitor c ON c.categoria = l.categoria
  JOIN bib_exemplares x        ON x.id_exemplar = e.id_exemplar
  JOIN bib_obras o             ON o.id_obra = x.id_obra
 WHERE e.data_devolucao IS NULL
   AND e.data_prevista < TRUNC(SYSDATE);

-- Fila de reservas abertas, com a posição de cada leitor.
CREATE OR REPLACE VIEW bib_vw_fila_reservas AS
SELECT r.id_obra,
       o.titulo,
       r.id_reserva,
       r.id_leitor,
       r.situacao,
       r.data_reserva,
       r.id_exemplar,
       r.prazo_retirada,
       CASE WHEN r.situacao = 'ATIVA'
            THEN ROW_NUMBER() OVER (PARTITION BY r.id_obra, r.situacao
                                    ORDER BY r.data_reserva, r.id_reserva)
       END AS posicao
  FROM bib_reservas r
  JOIN bib_obras o ON o.id_obra = r.id_obra
 WHERE r.situacao IN ('ATIVA', 'DISPONIVEL');
