# MATCH_RECOGNIZE `[12c+]`

## O que faz

Procura **padrões em sequências de linhas**, como uma expressão regular aplicada a linhas em vez de caracteres. Exemplos de perguntas que resolve:

- clientes cujo valor de pedido subiu em pedidos consecutivos;
- períodos de queda seguidos de recuperação (formato "V") numa série de preços;
- sessões de navegação: cliques com menos de 30 minutos entre si;
- sequências de status fora da ordem esperada (FATURADO antes de ABERTO).

Sem `MATCH_RECOGNIZE`, essas perguntas exigem várias camadas de `LAG`/`LEAD` e agrupamento por "ilhas" (seção 05, tópico 13).

## Estrutura

```sql
SELECT *
  FROM origem
 MATCH_RECOGNIZE (
     PARTITION BY id_cliente              -- uma busca independente por cliente
     ORDER BY data_pedido                 -- a sequência
     MEASURES                             -- o que devolver de cada ocorrência
         FIRST(id_pedido) AS pedido_inicial,
         LAST(id_pedido)  AS pedido_final,
         COUNT(*)         AS pedidos
     ONE ROW PER MATCH                    -- ou ALL ROWS PER MATCH
     AFTER MATCH SKIP PAST LAST ROW       -- onde recomeçar a busca
     PATTERN (inicio alta+)               -- o padrão, como regex
     DEFINE                               -- condição de cada variável
         alta AS valor > PREV(valor)
 );
```

## As partes

| Parte | Função |
|---|---|
| `PARTITION BY` | Divide os dados; o padrão é buscado dentro de cada grupo |
| `ORDER BY` | Ordem da sequência; obrigatória na prática |
| `PATTERN` | Sequência de variáveis com quantificadores: `*` (0 ou mais), `+` (1 ou mais), `?` (0 ou 1), `{n}`, `{n,}`, `{n,m}`; alternativa com `|` |
| `DEFINE` | Condição que uma linha precisa cumprir para ser classificada como aquela variável. Variável sem `DEFINE` (como `inicio`) aceita qualquer linha |
| `MEASURES` | Colunas de saída, com `FIRST`, `LAST`, `PREV`, `NEXT`, agregações, `MATCH_NUMBER()` e `CLASSIFIER()` |
| `ONE ROW PER MATCH` | Uma linha de resumo por ocorrência |
| `ALL ROWS PER MATCH` | Todas as linhas de cada ocorrência, com as medidas calculadas até ela |
| `AFTER MATCH SKIP` | `PAST LAST ROW` (padrão, não sobrepõe ocorrências), `TO NEXT ROW`, `TO LAST variavel`, `TO FIRST variavel` |

`PREV(valor)` é o valor da linha anterior na sequência; `CLASSIFIER()` devolve o nome da variável atribuída à linha; `MATCH_NUMBER()` numera as ocorrências dentro da partição.

## Como o padrão é aplicado

Para cada partição, o Oracle percorre as linhas na ordem, tentando encaixar o padrão a partir de cada posição. Os quantificadores são **gulosos**: `alta+` pega o maior número possível de linhas. Quando encontra uma ocorrência, devolve as medidas e recomeça conforme o `AFTER MATCH SKIP`.

## Armadilhas

- **Variável sem DEFINE aceita qualquer linha.** Por isso o padrão começa com `inicio`: a primeira linha não tem anterior para comparar.
- **Ordem não determinística.** Empate no `ORDER BY` torna o resultado imprevisível.
- **`ALL ROWS PER MATCH` com medidas agregadas** mostra o valor acumulado até cada linha, não o total da ocorrência. Use `FINAL` (`FINAL COUNT(*)`) para o total.

## Documentação oficial

- [Data Warehousing Guide — SQL for Pattern Matching](https://docs.oracle.com/en/database/oracle/oracle-database/19/dwhsg/sql-pattern-matching-data-warehouses.html)
