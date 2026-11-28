# Acumulado mensal e comparação com o mês anterior

## Cenário

Relatório de vendas por mês com: valor do mês, acumulado no ano, valor do mês anterior, variação percentual e valor do mesmo mês no ano anterior. Meses sem venda precisam aparecer com zero, senão o "mês anterior" de maio vira março.

## Os três passos

1. **Calendário de meses** gerado por SQL, independente das vendas (caso 08).
2. **LEFT JOIN** do calendário com as vendas agregadas por mês, com `NVL(valor, 0)`.
3. **Funções analíticas** sobre o resultado:

| Coluna | Expressão |
|---|---|
| Acumulado no ano | `SUM(valor) OVER (PARTITION BY ano ORDER BY mes)` |
| Mês anterior | `LAG(valor) OVER (ORDER BY mes)` |
| Variação % | `(valor - anterior) / NULLIF(anterior, 0) * 100` |
| Mesmo mês, ano anterior | `LAG(valor, 12) OVER (ORDER BY mes)` (só funciona porque não há buracos) |
| Média móvel de 3 meses | `AVG(valor) OVER (ORDER BY mes ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)` |

## Armadilhas

- **Sem o calendário**, `LAG(valor, 12)` pega a linha de 12 posições atrás, que não é o mesmo mês quando faltam meses. E o acumulado parece certo, mas o gráfico pula meses.
- **Divisão por zero**: mês anterior sem venda. `NULLIF(anterior, 0)` faz a variação ficar NULL em vez de erro; o relatório mostra "—".
- **Janela padrão do `SUM ... OVER (ORDER BY ...)`**: `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`. Com valores repetidos na coluna do `ORDER BY`, as linhas empatadas entram juntas no acumulado. Aqui o mês é único, sem problema; em acumulado por data com várias vendas no mesmo dia, use `ROWS`.
- **Status**: decida se cancelados entram (aqui, não) e deixe isso escrito no relatório.

## Documentação oficial

- [SQL Language Reference — Analytic Functions (windowing_clause)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Analytic-Functions.html)
- [SQL Language Reference — LAG](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/LAG.html)
