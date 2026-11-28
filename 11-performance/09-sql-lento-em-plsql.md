# SQL lento em PL/SQL: linha a linha versus em conjunto

Boa parte da lentidão em código PL/SQL não está numa consulta com plano ruim, e sim no **número de consultas**: um laço que faz uma instrução por linha, cada uma rápida, multiplicada por centenas de milhares. Nenhuma instrução aparece como lenta em `V$SQL`; o processo inteiro demora horas. Tom Kyte chamava de *slow by slow*.

## Os padrões, do mais lento ao mais rápido

| Padrão | Chamadas ao motor SQL | Observação |
|---|---|---|
| Laço com `SELECT` de apoio + `UPDATE` + `COMMIT` por linha | 3 por linha, mais a espera do COMMIT | O pior: cada COMMIT espera a gravação do redo em disco |
| Laço com `UPDATE` por linha | 1 por linha | Comum em código migrado de outras linguagens |
| `BULK COLLECT` + `FORALL` | Poucas por lote | Quando há regra por linha que o SQL não expressa bem (seção 09, tópico 08) |
| Uma instrução: `UPDATE` com subconsulta, `MERGE`, `INSERT ... SELECT` | 1 | O motor SQL faz tudo, com um plano só |

A pergunta antes de escrever o laço: **dá para escrever como uma instrução?** `CASE`, junção na subconsulta, funções analíticas e `MERGE` resolvem a maioria das regras "por linha".

## Outros padrões que multiplicam chamadas

- **N+1 consultas**: para cada cliente, uma consulta para somar os pedidos dele. Uma consulta com `GROUP BY` faz o mesmo de uma vez.
- **Function PL/SQL no `WHERE` ou no `SELECT`** de uma consulta grande, que por sua vez faz `SELECT` (seção 09, tópico 02). Cada linha: troca de contexto e uma consulta extra. Alternativas: JOIN; subconsulta escalar `(SELECT f(x) FROM dual)` para cache por valor; `DETERMINISTIC`, `RESULT_CACHE`, `PRAGMA UDF`.
- **COMMIT dentro do laço**: além do custo de cada COMMIT, quebra a atomicidade (metade do processo gravado se falhar no meio) e, num cursor aberto sobre a própria tabela, aumenta o risco de ORA-01555 (*snapshot too old*). Faça COMMIT no fim, ou em lotes grandes com um ponto de reinício pensado.

## Como achar o problema

- `V$SQL` ordenado por `EXECUTIONS`: uma instrução com centenas de milhares de execuções, cada uma barata, é o sinal.
- `DBMS_APPLICATION_INFO.SET_ACTION` no laço (seção 09, tópico 16) mostra o progresso em `V$SESSION`.
- O **profiler hierárquico** (`DBMS_HPROF`) mede o tempo gasto por subprograma PL/SQL e por instrução SQL chamada por ele.

## Documentação oficial

- [PL/SQL Language Reference — PL/SQL Optimization and Tuning](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-optimization-and-tuning.html)
- [Database Development Guide — Using the PL/SQL Hierarchical Profiler](https://docs.oracle.com/en/database/oracle/oracle-database/19/adfns/hierarchical-profiler.html)
