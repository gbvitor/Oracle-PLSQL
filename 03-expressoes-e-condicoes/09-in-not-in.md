# IN e NOT IN

## Formas

```sql
-- Lista de valores
WHERE uf IN ('SP', 'MG', 'GO')

-- Subquery
WHERE id_cliente IN (SELECT id_cliente FROM pedidos WHERE status = 'ABERTO')

-- Várias colunas ao mesmo tempo
WHERE (id_pedido, nr_item) IN ((1001, 1), (1002, 2))
```

`x IN (a, b, c)` equivale a `x = a OR x = b OR x = c`. `x NOT IN (a, b, c)` equivale a `x <> a AND x <> b AND x <> c`.

## NULL

| Situação | Comportamento |
|---|---|
| `NULL IN (...)` | UNKNOWN: a linha não entra |
| `x IN (1, NULL)` | Funciona para `x = 1`; o NULL da lista é inofensivo |
| `x NOT IN (1, NULL)` | **Nunca verdadeiro.** `x <> NULL` é UNKNOWN e derruba o `AND` inteiro |

Essa última linha é a armadilha mais conhecida de SQL. Com subquery, basta **uma** linha com NULL no resultado para o `NOT IN` não devolver nada:

```sql
-- Funcionários que nunca venderam: devolve 0 linhas, porque id_vendedor tem nulos
WHERE id_funcionario NOT IN (SELECT id_vendedor FROM pedidos)
```

Soluções, em ordem de preferência:

1. `NOT EXISTS (SELECT 1 FROM pedidos p WHERE p.id_vendedor = f.id_funcionario)`.
2. Filtrar o nulo na subquery: `... NOT IN (SELECT id_vendedor FROM pedidos WHERE id_vendedor IS NOT NULL)`.

Mesmo que a coluna não tenha nulos hoje, se ela **aceita** nulo, use `NOT EXISTS`: a consulta não deve depender de um dado que pode mudar.

## Limite de 1000 itens

Uma lista literal aceita no máximo 1000 expressões (ORA-01795). Acontece quando uma aplicação monta o `IN` concatenando códigos. Alternativas:

- tabela temporária ou coleção (`TABLE(SYS.ODCINUMBERLIST(...))`) com join ou `IN (SELECT ...)`;
- lista de tuplas `(1, x) IN ((1, a), (1, b), ...)`, que não tem o mesmo limite (contorno, não recomendação);
- várias listas unidas por `OR` (último recurso).

## IN ou EXISTS

Para `IN` com subquery e `EXISTS`, o otimizador gera o mesmo plano na maior parte dos casos (semi-join). A escolha é por clareza. Para `NOT IN` e `NOT EXISTS`, a diferença de **resultado** com NULL é o que decide.

## Documentação oficial

- [SQL Language Reference — IN Condition](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/IN-Condition.html)
