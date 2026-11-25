-- =============================================================================
-- Tópico : IN e NOT IN
-- Seção  : 03-expressoes-e-condicoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Lista de valores.
-- Esperado: 5 (SP 3, MG 1, GO 1)
SELECT COUNT(*) AS clientes
  FROM clientes
 WHERE uf IN ('SP', 'MG', 'GO');

-- 2. Subquery: clientes com pedido em aberto.
-- Esperado: 1, 6, 9
SELECT id_cliente, nome
  FROM clientes
 WHERE id_cliente IN (SELECT id_cliente FROM pedidos WHERE status = 'ABERTO')
 ORDER BY id_cliente;

-- 3. Várias colunas: itens específicos por chave composta.
-- Esperado: (1001, 1) produto 8 e (1002, 2) produto 11
SELECT id_pedido, nr_item, id_produto
  FROM itens_pedido
 WHERE (id_pedido, nr_item) IN ((1001, 1), (1002, 2))
 ORDER BY id_pedido;

-- 4. NULL dentro do IN é inofensivo.
-- Esperado: 3
SELECT COUNT(*) AS com_null_na_lista
  FROM clientes
 WHERE uf IN ('SP', NULL);

-- 5. NULL dentro do NOT IN derruba tudo.
-- Esperado: 9 sem nulo | 0 com nulo
SELECT (SELECT COUNT(*) FROM clientes WHERE uf NOT IN ('SP'))       AS sem_null,
       (SELECT COUNT(*) FROM clientes WHERE uf NOT IN ('SP', NULL)) AS com_null
  FROM dual;

-- 6. O caso real: funcionários que nunca venderam.
-- Esperado: 0 (errado) | 9 | 9
SELECT (SELECT COUNT(*) FROM funcionarios f
         WHERE f.id_funcionario NOT IN (SELECT id_vendedor FROM pedidos))        AS not_in,
       (SELECT COUNT(*) FROM funcionarios f
         WHERE f.id_funcionario NOT IN (SELECT id_vendedor FROM pedidos
                                         WHERE id_vendedor IS NOT NULL))         AS not_in_filtrado,
       (SELECT COUNT(*) FROM funcionarios f
         WHERE NOT EXISTS (SELECT 1 FROM pedidos p
                            WHERE p.id_vendedor = f.id_funcionario))             AS not_exists
  FROM dual;

-- 7. Limite de 1000 itens numa lista literal.
--    Monta e executa um IN com 1001 números por SQL dinâmico.
-- Esperado: ORA-01795 (o número máximo de expressões em uma lista é 1000)
DECLARE
    v_lista VARCHAR2(32767);
    v_qtd   NUMBER;
BEGIN
    FOR i IN 1 .. 1001 LOOP
        v_lista := v_lista || CASE WHEN i > 1 THEN ',' END || i;
    END LOOP;
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM clientes WHERE id_cliente IN (' || v_lista || ')'
       INTO v_qtd;
END;
/

-- Alternativa sem limite: coleção como tabela.
-- Esperado: 12 (todos os clientes estão entre 1 e 1001)
SELECT COUNT(*) AS clientes
  FROM clientes
 WHERE id_cliente IN (SELECT COLUMN_VALUE
                        FROM TABLE(SYS.ODCINUMBERLIST(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)));
