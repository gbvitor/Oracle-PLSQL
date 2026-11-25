-- =============================================================================
-- Tópico : Operadores aritméticos, concatenação e precedência
-- Seção  : 03-expressoes-e-condicoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Divisão sempre decimal; resto e parte inteira por função.
-- Esperado: 3.5 | 3 | 1 | -1
SELECT 7 / 2          AS divisao,
       TRUNC(7 / 2)   AS parte_inteira,
       MOD(7, 2)      AS resto,
       MOD(-7, 2)     AS resto_negativo
  FROM dual;

-- 2. Divisão por zero.
-- Esperado: ORA-01476 (divisor é igual a zero)
SELECT 10 / 0 FROM dual;

-- Evitar com NULLIF: divisão por NULL dá NULL, não erro.
-- Esperado: nulo
SELECT 10 / NULLIF(0, 0) AS seguro FROM dual;

-- 3. Precedência: * antes de +.
-- Esperado: 14 | 20
SELECT 2 + 3 * 4   AS sem_parenteses,
       (2 + 3) * 4 AS com_parenteses
  FROM dual;

-- 4. || tem a mesma precedência de + e -: avaliação da esquerda para a direita.
-- Esperado: ORA-01722 (número inválido), pois vira 'Total: 10' + 5
SELECT 'Total: ' || 10 + 5 AS texto FROM dual;

-- Esperado: Total: 15
SELECT 'Total: ' || (10 + 5) AS texto FROM dual;

-- 5. NULL: aritmética propaga, concatenação ignora.
-- Esperado: nulo | Ana Ribeiro - Comissao:
SELECT salario + pct_comissao                         AS soma,
       nome || ' - Comissao: ' || pct_comissao        AS texto
  FROM funcionarios
 WHERE id_funcionario = 100;

-- 6. Número convertido em texto sem formatação.
--    O separador decimal vem de NLS_NUMERIC_CHARACTERS da sessão.
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,';

-- Esperado: Taxa: .5 | Valor: 10.5
SELECT 'Taxa: '  || 0.5    AS sem_formato,
       'Valor: ' || 10.50  AS sem_casas
  FROM dual;

-- Com o padrão brasileiro, a mesma conversão implícita usa vírgula.
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ',.';

-- Esperado: Taxa: ,5 | Valor: 10,5 | Valor: 10,50
SELECT 'Taxa: '  || 0.5                            AS sem_formato,
       'Valor: ' || 10.50                          AS sem_casas,
       'Valor: ' || TO_CHAR(10.5, 'FM999G990D00')  AS formatado
  FROM dual;

ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,';

-- 7. Expressões sobre colunas: valor bruto, desconto e líquido de um item.
-- Esperado (pedido 1002, item 1): bruto 8988 | desconto 898.8 | liquido 8089.2
SELECT quantidade * preco_unitario                                   AS bruto,
       quantidade * preco_unitario * pct_desconto / 100              AS desconto,
       quantidade * preco_unitario * (1 - pct_desconto / 100)        AS liquido
  FROM itens_pedido
 WHERE id_pedido = 1002
   AND nr_item = 1;
