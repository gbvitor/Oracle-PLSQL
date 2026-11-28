-- =============================================================================
-- Projeto : 03 — Faturamento simplificado — carga de exemplo
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : 01-tabelas.sql, 02-pacote.sql
--
-- Cadastros e pedidos por INSERT; notas e baixas pela package, com datas fixas
-- de outubro e novembro de 2026. Dados fictícios.
-- =============================================================================

INSERT INTO fat_numeracao (serie) VALUES ('1');

INSERT INTO fat_clientes VALUES (1, 'Cliente A', 10000, 'S');
INSERT INTO fat_clientes VALUES (2, 'Cliente B', 3000,  'S');
INSERT INTO fat_clientes VALUES (3, 'Cliente C', 5000,  'N');

INSERT INTO fat_produtos VALUES (1, 'Produto 01', 120.00);
INSERT INTO fat_produtos VALUES (2, 'Produto 02', 45.90);
INSERT INTO fat_produtos VALUES (3, 'Produto 03', 899.00);
INSERT INTO fat_produtos VALUES (4, 'Produto 04', 12.35);

INSERT INTO fat_condicoes VALUES (1, 'À vista');
INSERT INTO fat_condicoes VALUES (2, '30/60/90 dias');
INSERT INTO fat_condicoes VALUES (3, '30/60 dias');

INSERT INTO fat_condicoes_parcelas VALUES (1, 1, 0,  100);
INSERT INTO fat_condicoes_parcelas VALUES (2, 1, 30, 33.33);
INSERT INTO fat_condicoes_parcelas VALUES (2, 2, 60, 33.33);
INSERT INTO fat_condicoes_parcelas VALUES (2, 3, 90, 33.34);
INSERT INTO fat_condicoes_parcelas VALUES (3, 1, 30, 50);
INSERT INTO fat_condicoes_parcelas VALUES (3, 2, 60, 50);

-- Pedido 1: 10 x 120,00 + 3 x 45,90 com 10% = 1.200,00 + 123,93 = 1.323,93
INSERT INTO fat_pedidos (id_pedido, id_cliente, id_condicao, data_pedido) VALUES (1, 1, 2, DATE '2026-10-05');
INSERT INTO fat_itens_pedido VALUES (1, 1, 1, 10, 120.00, 0);
INSERT INTO fat_itens_pedido VALUES (1, 2, 2, 3,  45.90,  10);

-- Pedido 2: 1 x 899,00 com 5% + 7 x 12,35 = 854,05 + 86,45 = 940,50
INSERT INTO fat_pedidos (id_pedido, id_cliente, id_condicao, data_pedido) VALUES (2, 2, 1, DATE '2026-10-20');
INSERT INTO fat_itens_pedido VALUES (2, 1, 3, 1, 899.00, 5);
INSERT INTO fat_itens_pedido VALUES (2, 2, 4, 7, 12.35,  0);

-- Pedido 3: 2 x 899,00 = 1.798,00
INSERT INTO fat_pedidos (id_pedido, id_cliente, id_condicao, data_pedido) VALUES (3, 1, 3, DATE '2026-11-10');
INSERT INTO fat_itens_pedido VALUES (3, 1, 3, 2, 899.00, 0);

-- Pedido 4: 3 x 899,00 = 2.697,00 (fica aberto; usado no teste de limite)
INSERT INTO fat_pedidos (id_pedido, id_cliente, id_condicao, data_pedido) VALUES (4, 2, 3, DATE '2026-11-25');
INSERT INTO fat_itens_pedido VALUES (4, 1, 3, 3, 899.00, 0);

-- Pedido 5: sem itens. Pedido 6: cliente inativo.
INSERT INTO fat_pedidos (id_pedido, id_cliente, id_condicao, data_pedido) VALUES (5, 1, 1, DATE '2026-11-26');
INSERT INTO fat_pedidos (id_pedido, id_cliente, id_condicao, data_pedido) VALUES (6, 3, 1, DATE '2026-11-26');
INSERT INTO fat_itens_pedido VALUES (6, 1, 4, 10, 12.35, 0);

DECLARE
    v_nota1 NUMBER;
    v_nota2 NUMBER;
    v_nota3 NUMBER;
    v_id    NUMBER;

    FUNCTION titulo (p_id_nota IN NUMBER, p_parcela IN NUMBER) RETURN NUMBER IS
        v NUMBER;
    BEGIN
        SELECT id_titulo INTO v FROM fat_titulos WHERE id_nota = p_id_nota AND parcela = p_parcela;
        RETURN v;
    END titulo;
BEGIN
    v_nota1 := fat_pkg_faturamento.faturar(1, '1', DATE '2026-10-05');
    v_nota2 := fat_pkg_faturamento.faturar(2, '1', DATE '2026-10-20');

    -- Nota 2, à vista, vencida em 20/10: pagamento parcial de 500,00 em 30/10.
    -- Encargos: 500,00 x (2% + 0,03% x 10 dias) = 11,50.
    v_id := fat_pkg_faturamento.baixar(titulo(v_nota2, 1), 500, DATE '2026-10-30');

    -- Nota 1, parcela 1, paga no vencimento: sem encargos.
    v_id := fat_pkg_faturamento.baixar(titulo(v_nota1, 1), 441.27, DATE '2026-11-04');

    v_nota3 := fat_pkg_faturamento.faturar(3, '1', DATE '2026-11-10');
END;
/

COMMIT;

-- Esperado:
--   1 1 1.323,93 EMITIDA | 1 2 940,50 EMITIDA | 1 3 1.798,00 EMITIDA
SELECT serie, numero, valor_total, situacao FROM fat_notas ORDER BY numero;

-- Esperado:
--   nota 1: 441,27 (04/11, PAGO) | 441,27 (04/12) | 441,39 (03/01/2027)
--   nota 2: 940,50 (20/10, pago 500,00, ABERTO)
--   nota 3: 899,00 (10/12) | 899,00 (09/01/2027)
SELECT n.numero, t.parcela, t.vencimento, t.valor, t.valor_pago, t.situacao
  FROM fat_titulos t
  JOIN fat_notas n ON n.id_nota = t.id_nota
 ORDER BY n.numero, t.parcela;

-- Esperado: cliente 1 em aberto 2.680,66 | cliente 2 em aberto 440,50 | cliente 3 0
SELECT id_cliente, limite_credito, em_aberto, disponivel FROM fat_vw_posicao_cliente ORDER BY id_cliente;
