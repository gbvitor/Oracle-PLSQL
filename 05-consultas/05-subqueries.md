# Subqueries

## Tipos

| Tipo | Devolve | Onde aparece | Operadores |
|---|---|---|---|
| Escalar | 1 linha, 1 coluna | `SELECT`, `WHERE`, `ORDER BY`, `SET`, `VALUES` | Qualquer expressão (seção 03, tópico 05) |
| De uma linha | 1 linha | `WHERE`, `HAVING` | `=`, `<>`, `<`, `>`... |
| De várias linhas | N linhas, 1 coluna | `WHERE`, `HAVING` | `IN`, `NOT IN`, `ANY`, `ALL` |
| De várias colunas | N linhas, N colunas | `WHERE` | `(a, b) IN (SELECT x, y ...)` |
| De existência | Qualquer | `WHERE` | `EXISTS`, `NOT EXISTS` |
| Inline view | Tabela | `FROM` | Como uma tabela (seção 02, tópico 02) |

Qualquer uma pode ser **correlacionada** (referencia colunas da consulta de fora e é avaliada, logicamente, uma vez por linha de fora) ou **não correlacionada** (independente, avaliada uma vez).

## Subquery de várias colunas

Compara pares de valores de uma vez. "Último pedido de cada cliente":

```sql
WHERE (id_cliente, data_pedido) IN (SELECT id_cliente, MAX(data_pedido)
                                      FROM pedidos
                                     GROUP BY id_cliente)
```

Se dois pedidos do mesmo cliente tiverem a mesma data máxima, os dois voltam: a subquery responde "pedidos com a data máxima", e não "um pedido por cliente". Para garantir um só, `ROW_NUMBER` (tópico 07).

## Subquery no HAVING

Compara o resultado de um grupo com um valor calculado sobre todos os grupos: "categorias que venderam acima da média das categorias".

## Subquery em UPDATE e DELETE

```sql
UPDATE produtos p
   SET preco_unitario = (SELECT ... WHERE x.id_produto = p.id_produto)
 WHERE EXISTS (SELECT 1 FROM ... WHERE x.id_produto = p.id_produto);

DELETE FROM itens_pedido
 WHERE id_pedido IN (SELECT id_pedido FROM pedidos WHERE status = 'CANCELADO');
```

O `WHERE EXISTS` no `UPDATE` impede que as linhas sem correspondência recebam NULL (seção 03, tópico 05). Mais padrões na seção 06.

## Como o Oracle executa

"Avaliada uma vez por linha" é o modelo lógico, não o físico. O otimizador costuma **desaninhar** (*unnest*) subqueries em `IN` e `EXISTS` e transformá-las em joins (semi-join, anti-join), e pode **fundir** (*merge*) inline views na consulta principal. Por isso, reescrever uma subquery como join "para ficar mais rápido" frequentemente não muda nada no plano. Confira o plano antes de reescrever (seção 11).

## Armadilhas

- **Subquery de uma linha que devolve várias**: ORA-01427, que só aparece quando os dados mudam.
- **`NOT IN` com subquery que pode ter NULL** (seção 03, tópico 09).
- **Correlação esquecida**: sem a condição que liga à consulta de fora, a subquery devolve o mesmo resultado para todas as linhas e o filtro deixa de fazer sentido, sem erro.
- **Nome de coluna ambíguo**: se a coluna citada na subquery não existe na tabela de dentro, o Oracle procura na de fora. `WHERE id_cliente IN (SELECT id_cliente FROM produtos)`: `produtos` não tem `id_cliente`, então ele usa o de fora, a condição vira sempre verdadeira, e não há erro. Qualifique as colunas com alias na subquery.

## Documentação oficial

- [SQL Language Reference — Using Subqueries](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Using-Subqueries.html)
