# Clientes sem compra no período (anti-join)

## Cenário

A equipe comercial quer a lista de clientes que **não compraram** em 2026, para uma ação de reativação, e a lista de quem comprou em 2025 mas não em 2026 (perdidos). Variações: produtos sem venda no mês, funcionários sem lançamento de ponto, notas sem título financeiro.

"Quem **não** tem" é um *anti-join*: as linhas de uma tabela sem correspondência em outra.

## As formas

| Forma | Observação |
|---|---|
| `NOT EXISTS (SELECT 1 FROM ... WHERE ...)` | **Recomendada.** Clara, correta com NULL, e o otimizador transforma em anti-join eficiente |
| `LEFT JOIN ... WHERE b.chave IS NULL` | Equivalente; o filtro do período vai no `ON`, não no `WHERE` |
| `NOT IN (SELECT coluna FROM ...)` | **Armadilha**: se a subconsulta devolver um NULL, o resultado é vazio |
| `MINUS` | Compara conjuntos de colunas; bom para listas de chaves, não traz as outras colunas |

## A armadilha do NOT IN

`x NOT IN (1, 2, NULL)` equivale a `x <> 1 AND x <> 2 AND x <> NULL`. A última comparação é desconhecida (lógica de três valores, seção 03, tópico 05), então a condição nunca é verdadeira: **nenhuma linha volta**. Sem erro, sem aviso.

No schema de exemplo: "funcionários que nunca venderam" com `NOT IN (SELECT id_vendedor FROM pedidos)` devolve zero linhas, porque os pedidos do site têm `id_vendedor` NULL. Com `NOT EXISTS`, devolve os nove funcionários que não são vendedores.

Se for usar `NOT IN`, filtre os NULL na subconsulta (`WHERE id_vendedor IS NOT NULL`), ou garanta `NOT NULL` na coluna. Melhor: use `NOT EXISTS` por hábito.

## O filtro do período no LEFT JOIN

```sql
-- Certo: o período limita o que pode casar
LEFT JOIN pedidos p ON p.id_cliente = c.id_cliente AND p.data_pedido >= DATE '2026-01-01'
WHERE p.id_pedido IS NULL

-- Errado: com o período no WHERE, o LEFT JOIN vira INNER e a lista sai vazia
LEFT JOIN pedidos p ON p.id_cliente = c.id_cliente
WHERE p.data_pedido >= DATE '2026-01-01' AND p.id_pedido IS NULL
```

## Documentação oficial

- [SQL Language Reference — EXISTS Condition](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/EXISTS-Condition.html)
- [SQL Language Reference — IN Condition](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/IN-Condition.html)
- [SQL Tuning Guide — Semijoins and Antijoins](https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/joins.html)
