# PIVOT e UNPIVOT `[11g+]`

## PIVOT: linhas viram colunas

```sql
SELECT *
  FROM (SELECT coluna_linha, coluna_pivo, valor FROM ...)
 PIVOT (SUM(valor)
        FOR coluna_pivo IN (2025 AS a2025, 2026 AS a2026));
```

Partes:

- **Origem**: quase sempre uma inline view com **só as colunas necessárias**.
- **Agregação**: `SUM`, `COUNT`, `MAX`... Pode haver mais de uma, separadas por vírgula; cada uma gera um conjunto de colunas.
- **`FOR ... IN (...)`**: a coluna cujos valores viram colunas e a lista **fixa** desses valores, com alias opcional.

## A regra implícita do PIVOT

Toda coluna da origem que não aparece na agregação nem no `FOR` vira **coluna de agrupamento**. Se a origem for a tabela inteira, cada coluna dela (inclusive a chave) entra no agrupamento, e o resultado sai com uma linha por registro em vez de uma por grupo. Por isso a origem é uma inline view com as colunas exatas: as de linha, a do pivô e a do valor.

## Lista de valores fixa

Os valores do `IN` precisam ser escritos na consulta. Não existe `IN (SELECT ...)` no PIVOT comum: o número de colunas de uma consulta precisa ser conhecido antes da execução. Alternativas para colunas dinâmicas:

- `PIVOT XML` com `IN (ANY)` ou subquery, que devolve um XML em vez de colunas;
- montar o SQL dinamicamente em PL/SQL (seção 09).

## Alternativa: agregação condicional

O mesmo resultado, em qualquer banco e sem a regra implícita:

```sql
SELECT id_vendedor,
       SUM(CASE WHEN ano = 2025 THEN valor END) AS a2025,
       SUM(CASE WHEN ano = 2026 THEN valor END) AS a2026
  FROM ...
 GROUP BY id_vendedor;
```

É mais longa, mas permite condições diferentes por coluna (faixas, combinações), mistura de agregações e totais na mesma linha. Muita gente prefere essa forma mesmo no Oracle.

## UNPIVOT: colunas viram linhas

```sql
SELECT *
  FROM tabela_larga
UNPIVOT (valor                          -- nome da nova coluna de valores
         FOR ano IN (a2025 AS 2025,     -- colunas de origem e o rótulo de cada uma
                     a2026 AS 2026));
```

Por padrão, linhas cujo valor é NULL são descartadas. `UNPIVOT INCLUDE NULLS (...)` as mantém.

Uso típico: normalizar planilhas importadas com uma coluna por mês, ou comparar colunas de uma mesma linha.

## Armadilhas

- **Origem com colunas demais** (a regra implícita).
- **Tipos diferentes no UNPIVOT.** Todas as colunas da lista precisam ter tipo compatível (ORA-01790).
- **Alias de coluna gerada.** Sem alias, o nome vem do valor (`'2025'`), e valores numéricos geram colunas com nome entre aspas. Dê alias.

## Documentação oficial

- [SQL Language Reference — SELECT (pivot_clause, unpivot_clause)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SELECT.html)
