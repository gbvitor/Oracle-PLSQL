# Último registro de cada grupo (último pedido de cada cliente)

## Cenário

A tela de clientes precisa mostrar, para cada cliente, a data, o número e a situação do **último pedido**, inclusive para quem nunca comprou. Variações do mesmo problema: último preço de cada produto, última movimentação de estoque, último status de cada chamado.

## Solução recomendada: ROW_NUMBER

```sql
SELECT c.id_cliente, c.nome, u.id_pedido, u.data_pedido, u.status
  FROM clientes c
  LEFT JOIN (SELECT p.*,
                    ROW_NUMBER() OVER (PARTITION BY p.id_cliente
                                       ORDER BY p.data_pedido DESC, p.id_pedido DESC) AS rn
               FROM pedidos p) u
    ON u.id_cliente = c.id_cliente
   AND u.rn = 1
 ORDER BY c.id_cliente;
```

- `PARTITION BY` define o grupo; `ORDER BY ... DESC` coloca o último em primeiro.
- **Desempate determinístico**: `id_pedido DESC` como segundo critério. Sem ele, dois pedidos na mesma data fazem o resultado variar entre execuções.
- A condição `rn = 1` fica no `ON` do LEFT JOIN, não no `WHERE`: no `WHERE`, os clientes sem pedido sumiriam.

## Alternativas

| Técnica | Quando |
|---|---|
| `ROW_NUMBER()` | Padrão: uma linha por grupo, com todas as colunas |
| `RANK()` com `= 1` | Quando empates devem aparecer todos (dois pedidos na mesma data e hora) |
| `MAX(...) KEEP (DENSE_RANK LAST ORDER BY ...)` | Só um ou dois valores do último registro, junto com outras agregações, sem subconsulta |
| `NOT EXISTS` de um registro mais novo | Portável para bancos sem funções analíticas; costuma ser mais lento |
| `CROSS APPLY` / `LATERAL` `[12c+]` com `FETCH FIRST 1 ROW` | Poucos grupos e índice em `(grupo, data)`: busca um registro por grupo pelo índice |
| `MAX(data)` + JOIN de volta | Evitar: devolve duplicados em empate e lê a tabela duas vezes |

A seção 05 (tópico 07) trata da técnica em detalhe, incluindo top-N por grupo.

## Desempenho

Com milhões de pedidos e poucos clientes consultados por vez (uma tela), `LATERAL` com índice em `pedidos(id_cliente, data_pedido)` busca uma linha por cliente. Para o relatório de **todos** os clientes, `ROW_NUMBER` com uma leitura completa e uma ordenação costuma ganhar.

## Documentação oficial

- [SQL Language Reference — Analytic Functions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Analytic-Functions.html)
- [SQL Language Reference — FIRST / LAST (KEEP)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/FIRST.html)
