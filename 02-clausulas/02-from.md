# FROM

## O que pode ir no FROM

| Origem | Exemplo |
|---|---|
| Tabela ou view | `FROM clientes` |
| Objeto de outro schema | `FROM vendas.clientes` |
| Inline view (subquery) | `FROM (SELECT ... ) v` |
| Nome definido no `WITH` | `WITH t AS (...) SELECT ... FROM t` |
| Coleção | `FROM TABLE(minha_colecao)` |
| Função de tabela | `FROM TABLE(minha_funcao_pipelined(...))` |
| JSON ou XML como tabela | `FROM JSON_TABLE(...)`, `FROM XMLTABLE(...)` |
| Subquery correlacionada | `FROM clientes c, LATERAL (SELECT ... WHERE x = c.id) v` `[12c+]` |
| Partição específica | `FROM pedidos PARTITION (p_2026)` |
| Outro banco | `FROM clientes@link_filial` |
| Amostra / passado | `FROM pedidos SAMPLE (10)`, `FROM pedidos AS OF TIMESTAMP ...` (tópico 13) |

## Alias de tabela

```sql
SELECT c.nome, p.id_pedido
  FROM clientes c
  JOIN pedidos  p ON p.id_cliente = c.id_cliente;
```

**No Oracle, alias de tabela não aceita `AS`.** `FROM clientes AS c` dá ORA-00933. `AS` só vale para alias de coluna. É uma das diferenças mais comuns ao trazer SQL de PostgreSQL, SQL Server ou MySQL.

Depois de definido o alias, a tabela só pode ser referida por ele: `clientes.nome` deixa de funcionar na mesma consulta.

## Inline view

Uma subquery no `FROM` funciona como uma tabela temporária, válida só durante a consulta:

```sql
SELECT v.id_cliente, v.total
  FROM (SELECT id_cliente, COUNT(*) AS total
          FROM pedidos
         GROUP BY id_cliente) v
 WHERE v.total >= 3;
```

Serve para filtrar pelo resultado de agregação ou de função analítica, para isolar uma etapa do cálculo e para controlar a granularidade antes de um join. Toda expressão dentro dela precisa de alias para ser usada de fora.

## Vírgula versus JOIN

```sql
-- Sintaxe antiga: tabelas separadas por vírgula, junção no WHERE
SELECT c.nome, p.id_pedido FROM clientes c, pedidos p WHERE p.id_cliente = c.id_cliente;

-- Sintaxe ANSI: junção no ON
SELECT c.nome, p.id_pedido FROM clientes c JOIN pedidos p ON p.id_cliente = c.id_cliente;
```

As duas dão o mesmo resultado e o mesmo plano. A ANSI separa a regra de ligação (`ON`) do filtro (`WHERE`), e esquecer a condição de ligação vira erro de sintaxe em vez de produto cartesiano silencioso. Use ANSI em código novo; joins em detalhe na seção 05.

## LATERAL `[12c+]`

Uma inline view comum não enxerga as outras tabelas do mesmo `FROM`. Com `LATERAL` (ou `CROSS APPLY` / `OUTER APPLY`), ela pode referenciar colunas das tabelas que vêm antes, e é executada para cada linha delas. Exemplo típico: "o último pedido de cada cliente". Seção 05, tópico 14.

## Armadilhas

- **`AS` no alias de tabela** (ORA-00933).
- **Esquecer a condição de join** na sintaxe com vírgula: 12 clientes × 24 pedidos = 288 linhas, sem erro.
- **Coluna ambígua** (ORA-00918) quando duas tabelas têm a coluna e ela não foi qualificada.
- **Inline view com `ORDER BY`** não garante a ordem do resultado final, exceto no padrão com `ROWNUM` (tópico 07). Ordene na consulta de fora.

## Documentação oficial

- [SQL Language Reference — SELECT (table_reference)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SELECT.html)
