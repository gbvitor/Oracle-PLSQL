# Plano real: DBMS_XPLAN.DISPLAY_CURSOR e GATHER_PLAN_STATISTICS

`DISPLAY_CURSOR` mostra o plano de um cursor que **já executou** e está no shared pool: é o plano que a execução realmente usou. Com as estatísticas de execução ligadas, mostra também quantas linhas **de fato** passaram por cada etapa.

```sql
SET SERVEROUTPUT OFF

SELECT /*+ GATHER_PLAN_STATISTICS */ COUNT(*)
  FROM pedidos
 WHERE status = 'CANCELADO';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(format => 'ALLSTATS LAST'));
```

## Os três cuidados

1. **`SET SERVEROUTPUT OFF`.** Sem argumentos, `DISPLAY_CURSOR` mostra o último SQL executado pela sessão. Com SERVEROUTPUT ligado, o SQL*Plus executa uma chamada a `DBMS_OUTPUT.GET_LINES` depois de cada comando, e é o plano *dela* que aparece ("NOTE: cannot fetch plan for SQL_ID...").
2. **Estatísticas de execução.** Sem elas, o plano real vem só com as estimativas. Para ter `A-Rows`, `Buffers` e `A-Time`: o hint `GATHER_PLAN_STATISTICS` na consulta, ou `ALTER SESSION SET statistics_level = ALL` para todas. Os dois custam um pouco de CPU; use para diagnóstico, não em produção permanente.
3. **Cursor de outra sessão.** Passe o `SQL_ID` (e o `CHILD_NUMBER`) achado em `V$SQL` ou `V$SESSION.SQL_ID`: `DISPLAY_CURSOR('abc123xyz', 0, 'ALLSTATS LAST')`.

## As colunas

| Coluna | Significa |
|---|---|
| `Starts` | Quantas vezes a operação foi executada (num nested loop, a operação interna roda uma vez por linha da externa) |
| `E-Rows` | Linhas **estimadas** pelo otimizador, **por execução** da operação |
| `A-Rows` | Linhas **reais**, somadas em todas as execuções |
| `A-Time` | Tempo real acumulado até aquela operação |
| `Buffers` | Leituras lógicas (blocos lidos do cache), acumuladas |
| `Reads` | Leituras físicas (do disco) |
| `OMem`, `1Mem`, `Used-Mem` | Memória para ordenação e hash |

`LAST` mostra só a última execução; sem ele, os valores são somados desde que o cursor entrou em memória.

## A leitura que resolve a maioria dos casos

Compare **`E-Rows × Starts`** com **`A-Rows`**, de baixo para cima. A primeira operação em que a diferença é grande (10 vezes ou mais) é onde o otimizador errou a cardinalidade, e tudo acima dela foi decidido com base nesse erro. A causa costuma ser:

- estatística ausente ou desatualizada (tópico 05);
- distribuição torta sem histograma (tópico 05);
- colunas correlacionadas (`uf = 'TO' AND cidade = 'Palmas'`: o otimizador multiplica as seletividades como se fossem independentes); corrige-se com estatísticas estendidas (column groups);
- função ou conversão sobre a coluna (tópico 06).

Outros formatos úteis: `'ALLSTATS LAST +PEEKED_BINDS'` (valores de bind usados no parse, tópico 07), `'TYPICAL +OUTLINE'`, `'ADAPTIVE'` (partes de plano adaptativo), `'+HINT_REPORT'` `[19c+]` (tópico 08).

## Documentação oficial

- [SQL Tuning Guide — Displaying Execution Plans: DISPLAY_CURSOR](https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/generating-and-displaying-execution-plans.html)
- [PL/SQL Packages and Types Reference — DBMS_XPLAN.DISPLAY_CURSOR](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_XPLAN.html)
