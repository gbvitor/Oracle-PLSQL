# HAVING

## O que faz

Filtra **grupos** depois do `GROUP BY`, da mesma forma que o `WHERE` filtra linhas antes dele. Por isso é o lugar das condições sobre agregações.

```sql
SELECT id_cliente, COUNT(*) AS pedidos
  FROM pedidos
 GROUP BY id_cliente
HAVING COUNT(*) >= 3;
```

## WHERE ou HAVING

| A condição é sobre... | Vai no | Exemplo |
|---|---|---|
| Valor de cada linha | `WHERE` | `status <> 'CANCELADO'` |
| Resultado de agregação | `HAVING` | `SUM(valor) > 20000` |
| Coluna do `GROUP BY` | `WHERE` (preferível) | `id_vendedor IS NOT NULL` |

Uma condição sobre coluna agrupada funciona nos dois lugares, mas no `WHERE` as linhas são descartadas **antes** de agrupar; no `HAVING`, o Oracle agrupa tudo e descarta depois. O otimizador às vezes move o filtro sozinho, mas não conte com isso.

A pergunta também muda o lugar: "clientes cujo **primeiro pedido** foi depois de junho de 2025" é condição sobre o grupo (`HAVING MIN(data_pedido) >= ...`); "pedidos feitos depois de junho de 2025" é condição sobre a linha (`WHERE data_pedido >= ...`). As duas dão resultados diferentes.

## Detalhes

- O `HAVING` pode usar agregação que não está no `SELECT`.
- Sem `GROUP BY`, a tabela inteira é um grupo só: `SELECT COUNT(*) FROM pedidos HAVING COUNT(*) > 100` devolve **nenhuma linha** (e não uma linha com zero).
- Alias do `SELECT` não vale no `HAVING` no 19c; `[23ai+]` vale.
- `HAVING` sem agregação nenhuma é quase sempre um `WHERE` no lugar errado.

## Documentação oficial

- [SQL Language Reference — SELECT (HAVING condition)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SELECT.html)
