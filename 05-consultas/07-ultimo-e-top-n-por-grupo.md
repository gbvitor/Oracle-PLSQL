# Último registro e top-N por grupo

"O último pedido de cada cliente", "os dois maiores pedidos de cada vendedor", "o preço vigente de cada produto": é uma das perguntas mais frequentes em SQL, e há várias formas de responder. A sintaxe de cada recurso está nas seções 02 e 04; aqui está a comparação.

## As formas

| Forma | Devolve | Empate na ordem | Traz outras colunas | Top-N (N > 1) |
|---|---|---|---|---|
| `ROW_NUMBER()` em inline view | Exatamente uma linha por grupo (ou N) | Escolhe uma, de forma arbitrária se não houver desempate | Sim | Sim |
| `RANK()` / `DENSE_RANK()` em inline view | Todas as empatadas | Traz todas | Sim | Sim |
| `(chave, data) IN (SELECT chave, MAX(data) ...)` | Linhas com a data máxima | Traz todas | Sim | Não |
| `NOT EXISTS` de linha posterior | Linhas sem outra mais recente | Traz todas | Sim | Não |
| `MAX(col) KEEP (DENSE_RANK LAST ORDER BY data)` | Um valor por grupo, numa agregação | Agrega as empatadas (`MAX`) | Uma expressão por coluna | Não |
| `LATERAL` / `CROSS APPLY` com `FETCH FIRST` | N linhas por grupo | `WITH TIES` ou desempate | Sim | Sim |

## Qual escolher

- **Padrão**: `ROW_NUMBER()` com um `ORDER BY` que termine numa coluna única. É legível, funciona para N = 1 e N > 1, e o resultado é determinístico.
- **Empates devem aparecer**: `RANK()` ou `DENSE_RANK()`.
- **Agregação com um ou dois valores "do último"** (o último vendedor, o último status) junto de outras agregações: `KEEP`, que evita uma subquery.
- **Poucos grupos e índice em (chave, data)**: `LATERAL` com `FETCH FIRST` pode ler só as primeiras linhas de cada grupo pelo índice, em vez de numerar a tabela inteira.

## Vigência

Uma variação comum: tabela de preços (ou de cadastro) com data de início de vigência, e a pergunta "qual o preço válido em tal data". É um "último registro por grupo" com filtro: entre as vigências com início menor ou igual à data, a mais recente.

```sql
SELECT *
  FROM (SELECT t.*,
               ROW_NUMBER() OVER (PARTITION BY id_produto ORDER BY inicio_vigencia DESC) AS rn
          FROM tabela_precos t
         WHERE inicio_vigencia <= DATE '2026-06-30')
 WHERE rn = 1;
```

## Documentação oficial

- [Data Warehousing Guide — SQL for Analysis and Reporting](https://docs.oracle.com/en/database/oracle/oracle-database/19/dwhsg/sql-analysis-reporting-data-warehouses.html)
