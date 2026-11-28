# Ranking de vendedores com empate

## Cenário

Classificar os vendedores por número de pedidos e por valor vendido, no período e por ano, e decidir o que fazer com os empates. Pedidos feitos pelo site (sem vendedor) não entram no ranking, mas o total geral precisa bater.

## As três funções

| Função | Com empate na 2ª posição | Uso |
|---|---|---|
| `ROW_NUMBER()` | 1, 2, 3, 4 (desempate arbitrário, se não houver outro critério) | Paginação, "um por grupo" |
| `RANK()` | 1, 2, 2, **4** | Ranking esportivo: quem empata divide a posição e a seguinte é pulada |
| `DENSE_RANK()` | 1, 2, 2, **3** | "Os 3 maiores valores", contando valores distintos |

A pergunta de negócio decide: "os três melhores vendedores" com `RANK() <= 3` pode devolver quatro pessoas (empate no terceiro lugar), o que é o certo para premiação; com `ROW_NUMBER() <= 3`, um dos empatados fica de fora por sorte.

Para que `ROW_NUMBER` não seja sorteio, acrescente um critério de desempate explícito e conhecido (maior valor, venda mais antiga, nome).

## Variações

- **Por período**: `RANK() OVER (PARTITION BY ano ORDER BY valor DESC)`.
- **Top N por grupo**: o ranking numa subconsulta, o filtro fora (função analítica não vai no `WHERE` da mesma consulta).
- **Percentil e faixas**: `PERCENT_RANK()`, `CUME_DIST()`, `NTILE(4)` para quartis.
- **Participação**: `RATIO_TO_REPORT(valor) OVER ()`.

## Documentação oficial

- [SQL Language Reference — RANK](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/RANK.html)
- [SQL Language Reference — DENSE_RANK](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/DENSE_RANK.html)
- [SQL Language Reference — ROW_NUMBER](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/ROW_NUMBER.html)
