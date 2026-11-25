# NULL

## O que é

`NULL` indica que o valor **não existe ou não é conhecido**. Não é zero, não é espaço e não é um valor: é a ausência de valor. Quase todo resultado inesperado em SQL tem um NULL por trás.

No schema de exemplo: `pct_comissao` é nulo para quem não vende, `limite_credito` é nulo para cliente ainda não analisado, `id_vendedor` é nulo para pedido feito pelo site.

## Lógica de três valores

Comparar qualquer coisa com NULL não dá verdadeiro nem falso: dá **desconhecido** (UNKNOWN). Isso vale até para `NULL = NULL`.

| Expressão | Resultado |
|---|---|
| `NULL = 1` | UNKNOWN |
| `NULL = NULL` | UNKNOWN |
| `NULL <> 1` | UNKNOWN |
| `NULL IS NULL` | TRUE |
| `TRUE AND UNKNOWN` | UNKNOWN |
| `FALSE AND UNKNOWN` | FALSE |
| `TRUE OR UNKNOWN` | TRUE |
| `FALSE OR UNKNOWN` | UNKNOWN |
| `NOT UNKNOWN` | UNKNOWN |

O `WHERE` só devolve as linhas em que a condição é **TRUE**. Linhas com UNKNOWN somem do resultado do mesmo jeito que as FALSE, e por isso `WHERE pct_comissao <> 5` não traz os funcionários sem comissão. Para testar nulo, existe só `IS NULL` e `IS NOT NULL`.

O `CHECK` funciona ao contrário: rejeita só FALSE. Uma linha com UNKNOWN passa. `CHECK (pct_comissao BETWEEN 0 AND 50)` aceita comissão nula; se ela não puder ser nula, é preciso `NOT NULL` também.

## NULL em expressões

- Aritmética com NULL dá NULL: `salario + NULL` é NULL.
- **Concatenação ignora NULL no Oracle**: `'Pedido ' || NULL` dá `'Pedido '`. Em PostgreSQL e no padrão SQL, o resultado seria NULL.
- Funções em geral devolvem NULL se recebem NULL, com exceções feitas justamente para tratá-lo: `NVL`, `NVL2`, `COALESCE`, `NULLIF`, `DECODE`, `LNNVL`, `CONCAT`, `REPLACE`.

## NULL em agregações, agrupamento e ordenação

- Funções de agregação **ignoram NULL**. `COUNT(*)` conta linhas; `COUNT(coluna)` conta valores não nulos.
- `AVG(pct_comissao)` é a média só de quem tem comissão. Para tratar ausência como zero: `AVG(NVL(pct_comissao, 0))`. Os dois resultados respondem perguntas diferentes.
- `SUM` de uma coluna em que todos os valores são nulos devolve NULL, não zero.
- `GROUP BY` e `DISTINCT` tratam todos os NULLs como **um mesmo grupo**.
- `ORDER BY` coloca NULL **por último** em ordem crescente e **primeiro** em decrescente. Para mudar: `NULLS FIRST` / `NULLS LAST`.

## NULL em constraints e índices

- `UNIQUE` aceita vários NULLs na mesma coluna, porque NULL não é igual a NULL.
- Em `UNIQUE` composta, linhas com **todas** as colunas nulas são aceitas repetidas; linhas com parte nula e o resto igual violam a constraint.
- Índice B-tree **não guarda** linhas em que todas as colunas indexadas são nulas. Por isso `WHERE coluna IS NULL` não usa um índice de coluna única. Solução comum: índice composto com uma constante, `(coluna, 0)`. Mais sobre isso na seção 11.

## CASE versus DECODE

`CASE x WHEN NULL THEN ...` nunca entra no ramo, porque compara `x = NULL`. `DECODE(x, NULL, ...)` entra, porque o `DECODE` trata dois NULLs como iguais. É uma das poucas diferenças reais entre os dois (seção 03).

## Armadilhas

- **`NOT IN` com NULL na lista não devolve nada.** `x NOT IN (1, 2, NULL)` equivale a `x <> 1 AND x <> 2 AND x <> NULL`; a última parte é UNKNOWN e derruba tudo. Com subquery, basta uma linha nula no resultado. Use `NOT EXISTS` ou filtre `IS NOT NULL` na subquery.
- **`<>` esconde os nulos.** "Funcionários com comissão diferente de 5" precisa decidir se quem não tem comissão entra: `WHERE pct_comissao <> 5 OR pct_comissao IS NULL`, ou `WHERE LNNVL(pct_comissao = 5)`.
- **Média e contagem com sentidos diferentes.** `COUNT(email)` não é número de clientes.
- **String vazia vira NULL.** `UPDATE clientes SET email = ''` grava NULL.
- **Join por coluna nula não liga.** `ON a.x = b.x` não encontra par quando `x` é nulo dos dois lados.

## Documentação oficial

- [SQL Language Reference — Nulls](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Nulls.html)
