-- =============================================================================
-- Projeto : 01 — Controle de estoque — carga de exemplo
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : 01-tabelas.sql, 02-pacote.sql
--
-- Cadastros por INSERT; movimentos pela package (o saldo nasce consistente).
-- Dados fictícios, de novembro de 2026.
-- =============================================================================

INSERT INTO est_depositos VALUES (1, 'Almoxarifado central');
INSERT INTO est_depositos VALUES (2, 'Loja');

INSERT INTO est_produtos VALUES (1, 'PAR-001', 'Parafuso 6 mm, caixa com 100', 'CX', 10,  'S');
INSERT INTO est_produtos VALUES (2, 'POR-001', 'Porca 6 mm, caixa com 100',    'CX', 10,  'S');
INSERT INTO est_produtos VALUES (3, 'ARR-001', 'Arruela 6 mm, caixa com 100',  'CX', 5,   'S');
INSERT INTO est_produtos VALUES (4, 'FIT-001', 'Fita isolante 19 mm',          'UN', 20,  'S');
INSERT INTO est_produtos VALUES (5, 'CAB-001', 'Cabo flexível 2,5 mm',         'M',  100, 'S');
INSERT INTO est_produtos VALUES (6, 'LAM-001', 'Lâmpada incandescente 60 W',   'UN', 0,   'N');

DECLARE
    v_id NUMBER;
BEGIN
    v_id := est_pkg_estoque.entrada(1, 1, 100, 'NF-1001', DATE '2026-11-02');
    v_id := est_pkg_estoque.entrada(2, 1, 80,  'NF-1001', DATE '2026-11-02');
    v_id := est_pkg_estoque.entrada(3, 1, 50,  'NF-1001', DATE '2026-11-02');
    v_id := est_pkg_estoque.entrada(4, 1, 30,  'NF-1002', DATE '2026-11-03');
    v_id := est_pkg_estoque.entrada(5, 1, 500, 'NF-1002', DATE '2026-11-03');

    v_id := est_pkg_estoque.transferir(1, 1, 2, 20,    'TR-0001', DATE '2026-11-05');
    v_id := est_pkg_estoque.transferir(5, 1, 2, 150.5, 'TR-0001', DATE '2026-11-05');

    v_id := est_pkg_estoque.saida(1, 1, 35,    'REQ-0501', DATE '2026-11-10');
    v_id := est_pkg_estoque.saida(2, 1, 72,    'REQ-0501', DATE '2026-11-10');
    v_id := est_pkg_estoque.saida(1, 2, 8,     'VND-9001', DATE '2026-11-12');
    v_id := est_pkg_estoque.saida(5, 2, 37.25, 'VND-9001', DATE '2026-11-12');
    v_id := est_pkg_estoque.saida(4, 1, 12,    'REQ-0502', DATE '2026-11-20');

    v_id := est_pkg_estoque.ajustar(3, 1, 47, 'Inventário de novembro', DATE '2026-11-25');
    v_id := est_pkg_estoque.ajustar(4, 1, 19, 'Inventário de novembro', DATE '2026-11-25');
END;
/

COMMIT;

-- Esperado:
--   1 1 45      | 1 2 12
--   2 1 8
--   3 1 47
--   4 1 19
--   5 1 349,5   | 5 2 113,25
SELECT id_produto, id_deposito, quantidade
  FROM est_saldos
 ORDER BY id_produto, id_deposito;
