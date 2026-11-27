# LATERAL, CROSS APPLY e OUTER APPLY `[12c+]`

## O problema que resolvem

Uma inline view comum **não enxerga** as outras tabelas do mesmo `FROM`:

```sql
-- ORA-00904: c.id_cliente não é visível dentro da inline view
FROM clientes c,
     (SELECT ... FROM pedidos p WHERE p.id_cliente = c.id_cliente FETCH FIRST 2 ROWS ONLY) u
```

Com `LATERAL`, `CROSS APPLY` ou `OUTER APPLY`, a subquery do `FROM` passa a poder usar colunas das tabelas que vêm **antes** dela, e é avaliada (logicamente) para cada linha delas. É uma subquery correlacionada que devolve **várias linhas e várias colunas**, coisa que uma subquery escalar não pode fazer.

## As três formas

| Forma | Linhas da esquerda sem resultado na subquery | Origem |
|---|---|---|
| `, LATERAL (subquery) alias` | Somem | Padrão SQL |
| `CROSS APPLY (subquery) alias` | Somem | SQL Server, adotada pelo Oracle |
| `OUTER APPLY (subquery) alias` | **Ficam**, com NULL nas colunas da subquery | SQL Server, adotada pelo Oracle |

`LATERAL` e `CROSS APPLY` são equivalentes. `OUTER APPLY` é o "left join" da família.

## Usos

- **Top-N por linha**: os 2 últimos pedidos de cada cliente, os 3 produtos mais vendidos de cada categoria.
- **Expandir uma linha em várias**: quebrar uma lista delimitada da própria linha (seção 04, tópico 10), gerar N parcelas a partir da quantidade de parcelas do registro.
- **Calcular uma vez e reutilizar**: uma expressão longa calculada no `APPLY` e referenciada por nome em várias colunas, em vez de repetida.
- **Chamar função de tabela** passando colunas da linha: `CROSS APPLY TABLE(minha_funcao(t.id))`.

## Desempenho

Com índice na coluna de correlação (por exemplo, `pedidos (id_cliente, data_pedido)`), o `APPLY` com `FETCH FIRST n` lê só as primeiras linhas de cada grupo pelo índice. Com muitos grupos e sem índice, `ROW_NUMBER()` sobre a tabela inteira costuma ser melhor: uma leitura só, em vez de uma por linha da esquerda.

## Documentação oficial

- [SQL Language Reference — SELECT (cross_outer_apply_clause, LATERAL)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SELECT.html)
