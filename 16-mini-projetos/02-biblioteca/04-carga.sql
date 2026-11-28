-- =============================================================================
-- Projeto : 02 — Biblioteca — carga de exemplo
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : 01-tabelas.sql, 02-pacote.sql
--
-- Cadastros por INSERT; empréstimos e reservas pela package, com datas fixas de
-- novembro de 2026. Títulos, autores e leitores são fictícios.
-- =============================================================================

INSERT INTO bib_categorias_leitor VALUES ('ALUNO',     3, 7,  1.50, 1);
INSERT INTO bib_categorias_leitor VALUES ('PROFESSOR', 5, 14, 1.00, 2);

INSERT INTO bib_leitores VALUES (1, 'Aluno 01',     'ALUNO',     'S');
INSERT INTO bib_leitores VALUES (2, 'Aluno 02',     'ALUNO',     'S');
INSERT INTO bib_leitores VALUES (3, 'Professor 01', 'PROFESSOR', 'S');
INSERT INTO bib_leitores VALUES (4, 'Aluno 04',     'ALUNO',     'N');
INSERT INTO bib_leitores VALUES (5, 'Aluno 05',     'ALUNO',     'S');

INSERT INTO bib_obras VALUES (1, 'Fundamentos de bancos de dados', 'Autor A', 2019);
INSERT INTO bib_obras VALUES (2, 'Estruturas de dados na prática', 'Autor B', 2021);
INSERT INTO bib_obras VALUES (3, 'Redes de computadores',          'Autor C', 2018);
INSERT INTO bib_obras VALUES (4, 'Estatística básica',             'Autor D', 2010);
INSERT INTO bib_obras VALUES (5, 'Lógica de programação',          'Autor E', 2022);

INSERT INTO bib_exemplares (id_exemplar, id_obra) VALUES (101, 1);
INSERT INTO bib_exemplares (id_exemplar, id_obra) VALUES (102, 1);
INSERT INTO bib_exemplares (id_exemplar, id_obra) VALUES (201, 2);
INSERT INTO bib_exemplares (id_exemplar, id_obra) VALUES (301, 3);
INSERT INTO bib_exemplares (id_exemplar, id_obra, situacao) VALUES (401, 4, 'BAIXADO');
INSERT INTO bib_exemplares (id_exemplar, id_obra) VALUES (501, 5);
INSERT INTO bib_exemplares (id_exemplar, id_obra) VALUES (502, 5);
INSERT INTO bib_exemplares (id_exemplar, id_obra) VALUES (503, 5);

DECLARE
    v_id    NUMBER;
    v_multa NUMBER;
BEGIN
    -- Previstas: 09/11, 09/11 (aluno, 7 dias) e 17/11 (professor, 14 dias).
    v_id := bib_pkg_biblioteca.emprestar(1, 101, DATE '2026-11-02');
    v_id := bib_pkg_biblioteca.emprestar(2, 201, DATE '2026-11-02');
    v_id := bib_pkg_biblioteca.emprestar(3, 102, DATE '2026-11-03');

    -- A obra 2 só tem o exemplar 201, emprestado: duas reservas na fila.
    v_id := bib_pkg_biblioteca.reservar(1, 2, TO_DATE('2026-11-04 10:00', 'YYYY-MM-DD HH24:MI'));
    v_id := bib_pkg_biblioteca.reservar(3, 2, TO_DATE('2026-11-05 15:30', 'YYYY-MM-DD HH24:MI'));

    -- No prazo: sem multa.
    v_multa := bib_pkg_biblioteca.devolver(101, DATE '2026-11-09');

    -- Três dias de atraso (aluno, 1,50 por dia): 4,50. O 201 fica separado para o Aluno 01.
    v_multa := bib_pkg_biblioteca.devolver(201, DATE '2026-11-12');

    -- O Aluno 01 retira a reserva: prevista 20/11.
    v_id := bib_pkg_biblioteca.emprestar(1, 201, DATE '2026-11-13');

    -- O Professor 01 renova o 102 antes de vencer: prevista 16/11 + 14 = 30/11.
    SELECT id_emprestimo INTO v_id
      FROM bib_emprestimos
     WHERE id_exemplar = 102 AND data_devolucao IS NULL;
    bib_pkg_biblioteca.renovar(v_id, DATE '2026-11-16');
END;
/

COMMIT;

-- Esperado:
--   101 DISPONIVEL | 102 EMPRESTADO | 201 EMPRESTADO | 301 DISPONIVEL
--   401 BAIXADO    | 501, 502, 503 DISPONIVEL
SELECT id_exemplar, situacao FROM bib_exemplares ORDER BY id_exemplar;

-- Esperado:
--   101 1 02/11 09/11 devolvido 09/11 multa 0
--   201 2 02/11 09/11 devolvido 12/11 multa 4,50 (não paga)
--   102 3 03/11 30/11 aberto, 1 renovação
--   201 1 13/11 20/11 aberto
SELECT id_exemplar, id_leitor, data_emprestimo, data_prevista, data_devolucao,
       renovacoes, valor_multa, multa_paga
  FROM bib_emprestimos
 ORDER BY id_emprestimo;

-- Esperado: reserva do Aluno 01 ATENDIDA; do Professor 01 ATIVA (primeiro da fila)
SELECT id_reserva, id_obra, id_leitor, situacao, id_exemplar FROM bib_reservas ORDER BY id_reserva;
