# Funções analíticas I: ROW_NUMBER, RANK, DENSE_RANK, NTILE

## O que é uma função analítica

Uma função de agregação colapsa o grupo numa linha. Uma função **analítica** calcula sobre um grupo de linhas, mas **mantém todas as linhas** no resultado, cada uma com o seu valor. A cláusula `OVER` define o grupo e a ordem:

```sql
funcao() OVER (
    [PARTITION BY colunas]     -- divide em grupos independentes (opcional)
    [ORDER BY colunas]         -- ordem dentro de cada grupo
    [janela]                   -- tópico 09
)
```

Sem `PARTITION BY`, o resultado inteiro é um grupo só. As funções analíticas são calculadas depois do `WHERE`, `GROUP BY` e `HAVING`, e por isso não podem ser usadas nessas cláusulas (seção 01, tópico 09).

## Funções de posição

| Função | Empate | Exemplo com valores 5, 5, 4, 3 |
|---|---|---|
| `ROW_NUMBER()` | Números diferentes; ordem entre empatados é arbitrária | 1, 2, 3, 4 |
| `RANK()` | Mesmo número; **pula** posições depois | 1, 1, 3, 4 |
| `DENSE_RANK()` | Mesmo número; **não pula** | 1, 1, 2, 3 |
| `NTILE(n)` | Divide em `n` grupos de tamanho o mais igual possível | Quartis com `NTILE(4)` |
| `PERCENT_RANK()` | `(RANK - 1) / (linhas - 1)`, de 0 a 1 | |
| `CUME_DIST()` | Fração de linhas com valor menor ou igual | |

Qual usar:

- **ROW_NUMBER**: quando é preciso exatamente uma linha por posição: deduplicação, top-N por grupo, paginação. Termine o `ORDER BY` com uma coluna única para que o resultado seja reproduzível.
- **RANK**: classificação "esportiva": dois em primeiro, o próximo é terceiro.
- **DENSE_RANK**: "os 3 maiores valores distintos", níveis sem buracos.
- **NTILE**: quartis, decis, faixas de mesma quantidade de linhas.

## Top-N por grupo

O padrão mais usado das funções de posição:

```sql
SELECT *
  FROM (SELECT p.*,
               ROW_NUMBER() OVER (PARTITION BY id_categoria ORDER BY qtd DESC, id_produto) AS rn
          FROM ...) 
 WHERE rn <= 2;
```

A numeração é calculada numa inline view (ou `WITH`) e filtrada fora.

## Deduplicação

Para manter só uma linha de cada grupo de repetidos (a mais recente, por exemplo):

```sql
DELETE FROM tabela
 WHERE ROWID IN (SELECT rid
                   FROM (SELECT ROWID AS rid,
                                ROW_NUMBER() OVER (PARTITION BY chave_natural
                                                   ORDER BY data_alteracao DESC) AS rn
                           FROM tabela)
                  WHERE rn > 1);
```

## Armadilhas

- **`ROW_NUMBER` com empate no `ORDER BY`**: a linha escolhida pode mudar entre execuções.
- **`NTILE` com quantidade não divisível**: os primeiros grupos ficam com uma linha a mais (10 linhas em 4 grupos: 3, 3, 2, 2).
- **Filtrar pela função no mesmo nível** (`WHERE ROW_NUMBER() OVER ... = 1`) dá ORA-30483.

## Documentação oficial

- [SQL Language Reference — Analytic Functions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Analytic-Functions.html)
- [Data Warehousing Guide — SQL for Analysis and Reporting](https://docs.oracle.com/en/database/oracle/oracle-database/19/dwhsg/sql-analysis-reporting-data-warehouses.html)
