# 11 — Performance

Ler o que o otimizador decidiu e entender por que uma consulta está lenta antes de mexer nela.

## Preparação

O schema de exemplo é pequeno demais para o otimizador variar de plano. Rode [00-preparar.sql](00-preparar.sql) uma vez: ele cria `TMP_PERF_CLIENTES` (2 mil linhas) e `TMP_PERF_PEDIDOS` (200 mil linhas), com distribuição conhecida e um status de propósito desbalanceado (98,9% `ENTREGUE`). [99-limpar.sql](99-limpar.sql) remove as duas. Os tópicos 05 e 07 alteram as estatísticas e as devolvem ao estado inicial no fim.

Planos esperados descrevem a forma (operações, predicados, ordem de grandeza das linhas). Custo, bytes e tempo variam com a versão e a máquina; quando o plano sair diferente, compare as estimativas de linhas para entender o motivo.

## Tópicos

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 01 | Como o Oracle executa uma consulta: parse, otimização, execução; hard e soft parse | [md](01-como-o-oracle-executa.md) | [sql](01-como-o-oracle-executa.sql) |
| 02 | EXPLAIN PLAN e DBMS_XPLAN.DISPLAY: formatos, access e filter, limites | [md](02-explain-plan.md) | [sql](02-explain-plan.sql) |
| 03 | Plano real: DBMS_XPLAN.DISPLAY_CURSOR, GATHER_PLAN_STATISTICS, E-Rows contra A-Rows | [md](03-display-cursor.md) | [sql](03-display-cursor.sql) |
| 04 | Lendo um plano: ordem, métodos de acesso, junções, cardinalidade | [md](04-lendo-um-plano.md) | [sql](04-lendo-um-plano.sql) |
| 05 | Estatísticas: DBMS_STATS, histogramas, desatualizadas, valor fora da faixa | [md](05-estatisticas.md) | [sql](05-estatisticas.sql) |
| 06 | Quando um índice é usado e quando é ignorado: função, conversão implícita, clustering factor | [md](06-quando-o-indice-e-usado.md) | [sql](06-quando-o-indice-e-usado.sql) |
| 07 | Bind variables, bind peeking e adaptive cursor sharing | [md](07-bind-variables.md) | [sql](07-bind-variables.sql) |
| 08 | Hints: quando fazem sentido, os mais comuns, HINT_REPORT, alternativas | [md](08-hints.md) | [sql](08-hints.sql) |
| 09 | SQL lento em PL/SQL: linha a linha, FORALL, uma instrução, N+1, function no SELECT | [md](09-sql-lento-em-plsql.md) | [sql](09-sql-lento-em-plsql.sql) |
| 10 | Ferramentas: AUTOTRACE, SQL trace e TKPROF, SQL Monitor, AWR, ASH e licenciamento | [md](10-ferramentas.md) | [sql](10-ferramentas.sql) |

Continua em [12 — SQL*Plus e SQLcl](../12-sqlplus-sqlcl/README.md).
