-- =============================================================================
-- Tópico : UPDATE — simples, várias colunas, a partir de outra tabela
-- Seção  : 06-dml-e-transacoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); usuário com CREATE TABLE
-- Todas as alterações no schema de exemplo terminam em ROLLBACK.
-- =============================================================================

-- 1. Conferir antes de alterar: o mesmo WHERE num SELECT.
-- Esperado: 2 (produtos 13 e 14)
SELECT COUNT(*) FROM produtos WHERE id_categoria = 7;

-- Esperado: 2 linhas atualizadas
UPDATE produtos
   SET preco_unitario = ROUND(preco_unitario * 1.05, 2)
 WHERE id_categoria = 7;

-- Esperado: 13 -> 828.45 | 14 -> 303.45
SELECT id_produto, preco_unitario FROM produtos WHERE id_categoria = 7;

ROLLBACK;

-- 2. Várias colunas.
UPDATE clientes SET cidade = 'Araguaina', uf = 'TO' WHERE id_cliente = 6;

SELECT id_cliente, cidade, uf FROM clientes WHERE id_cliente = 6;

ROLLBACK;

-- Tabela de origem para os exemplos 3 a 5: novos endereços de 2 clientes.
CREATE TABLE tmp_novos_enderecos (
    id_cliente NUMBER CONSTRAINT pk_tmp_novos_enderecos PRIMARY KEY,
    cidade     VARCHAR2(60),
    uf         CHAR(2)
);
INSERT INTO tmp_novos_enderecos VALUES (4, 'Anapolis', 'GO');
INSERT INTO tmp_novos_enderecos VALUES (7, 'Londrina', 'PR');
COMMIT;

-- 3. Subquery de várias colunas com WHERE EXISTS.
-- Esperado: 2 linhas atualizadas
UPDATE clientes c
   SET (cidade, uf) = (SELECT n.cidade, n.uf
                         FROM tmp_novos_enderecos n
                        WHERE n.id_cliente = c.id_cliente)
 WHERE EXISTS (SELECT 1 FROM tmp_novos_enderecos n WHERE n.id_cliente = c.id_cliente);

-- Esperado: 4 Anapolis GO | 7 Londrina PR
SELECT id_cliente, cidade, uf FROM clientes WHERE id_cliente IN (4, 7);

ROLLBACK;

-- 4. Inline view atualizável: funciona porque tmp_novos_enderecos tem
--    PRIMARY KEY em id_cliente (clientes é key-preserved no join).
-- Esperado: 2 linhas atualizadas
UPDATE (SELECT c.cidade AS cidade_atual, c.uf AS uf_atual,
               n.cidade AS cidade_nova,  n.uf AS uf_nova
          FROM clientes            c
          JOIN tmp_novos_enderecos n ON n.id_cliente = c.id_cliente)
   SET cidade_atual = cidade_nova,
       uf_atual     = uf_nova;

ROLLBACK;

-- 5. Sem a constraint, o mesmo UPDATE é recusado, ainda que os dados sejam únicos.
ALTER TABLE tmp_novos_enderecos DROP CONSTRAINT pk_tmp_novos_enderecos;

-- Esperado: ORA-01779 (não é possível modificar uma coluna que mapeie uma tabela não preservada por chave)
UPDATE (SELECT c.cidade AS cidade_atual, n.cidade AS cidade_nova
          FROM clientes            c
          JOIN tmp_novos_enderecos n ON n.id_cliente = c.id_cliente)
   SET cidade_atual = cidade_nova;

-- [23ai+] Join direto no UPDATE. No 19c, erro de sintaxe.
-- UPDATE clientes c
--    SET c.cidade = n.cidade, c.uf = n.uf
--   FROM tmp_novos_enderecos n
--  WHERE n.id_cliente = c.id_cliente

DROP TABLE tmp_novos_enderecos PURGE;

-- 6. Linhas "atualizadas" com o mesmo valor também contam e geram trabalho.
-- Esperado: 15 linhas atualizadas (nenhuma mudou de verdade)
UPDATE produtos SET ativo = ativo;

ROLLBACK;

-- Filtrando o que realmente muda.
-- Esperado: 1 linha atualizada (só o produto 15 estava inativo)
UPDATE produtos SET ativo = 'S' WHERE ativo <> 'S';

ROLLBACK;

-- 7. Chave primária com filhos não pode mudar.
-- Esperado: ORA-02292 (registro filho localizado)
UPDATE clientes SET id_cliente = 100 WHERE id_cliente = 1;
