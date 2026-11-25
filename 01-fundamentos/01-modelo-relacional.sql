-- =============================================================================
-- Tópico : Modelo relacional — chaves e integridade na prática
-- Seção  : 01-fundamentos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- Os comandos com erro são intencionais: mostram a constraint barrando o dado.
-- =============================================================================

-- 1. Chaves e constraints do schema, lidas do dicionário de dados.
--    constraint_type: P = primária, U = única, R = estrangeira, C = check/not null
SELECT c.table_name,
       c.constraint_name,
       c.constraint_type,
       LISTAGG(cc.column_name, ', ') WITHIN GROUP (ORDER BY cc.position) AS colunas,
       c.r_constraint_name AS referencia
  FROM user_constraints  c
  JOIN user_cons_columns cc
    ON cc.constraint_name = c.constraint_name
 WHERE c.constraint_type IN ('P', 'U', 'R')
 GROUP BY c.table_name, c.constraint_name, c.constraint_type, c.r_constraint_name
 ORDER BY c.table_name, c.constraint_type, c.constraint_name;

-- 2. Integridade de entidade: PK repetida.
--    Esperado: ORA-00001 (violação de restrição exclusiva PK_CLIENTES)
INSERT INTO clientes (id_cliente, nome, tipo_pessoa, documento, cidade, uf)
VALUES (1, 'Cliente Duplicado', 'F', '29999999999', 'Recife', 'PE');

-- 3. Integridade referencial: pedido de cliente que não existe.
--    Esperado: ORA-02291 (chave mãe não localizada, FK_PEDIDOS_CLIENTE)
INSERT INTO pedidos (id_pedido, id_cliente, data_pedido)
VALUES (9001, 999, SYSDATE);

-- 4. Integridade referencial: apagar cliente que tem pedidos.
--    Esperado: ORA-02292 (registro filho localizado, FK_PEDIDOS_CLIENTE)
DELETE FROM clientes WHERE id_cliente = 1;

-- 5. Integridade de domínio: valor fora do CHECK.
--    Esperado: ORA-02290 (restrição de verificação CK_CLIENTES_TIPO violada)
INSERT INTO clientes (id_cliente, nome, tipo_pessoa, documento, cidade, uf)
VALUES (90, 'Tipo Invalido', 'X', '29999999998', 'Recife', 'PE');

-- 6. ON DELETE CASCADE: apagar o pedido apaga os itens junto.
--    Conferir antes e depois, e desfazer com ROLLBACK.
-- Esperado: 3
SELECT COUNT(*) AS itens_do_pedido_1001 FROM itens_pedido WHERE id_pedido = 1001;

DELETE FROM pedidos WHERE id_pedido = 1001;

-- Esperado: 0
SELECT COUNT(*) AS itens_do_pedido_1001 FROM itens_pedido WHERE id_pedido = 1001;

ROLLBACK;

-- Esperado: 3 de novo
SELECT COUNT(*) AS itens_do_pedido_1001 FROM itens_pedido WHERE id_pedido = 1001;

-- 7. Por que o preço do item não é redundância: comparar preço praticado
--    com o preço de tabela atual.
SELECT i.id_pedido,
       p.nome                    AS produto,
       i.preco_unitario          AS preco_praticado,
       p.preco_unitario          AS preco_tabela_hoje,
       p.preco_unitario - i.preco_unitario AS diferenca
  FROM itens_pedido i
  JOIN produtos     p ON p.id_produto = i.id_produto
 WHERE i.preco_unitario <> p.preco_unitario
 ORDER BY i.id_pedido, i.nr_item;
