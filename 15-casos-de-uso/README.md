# 15 — Casos de uso

Problemas que aparecem com frequência, resolvidos de ponta a ponta: o cenário, as alternativas com suas armadilhas e um script com os resultados esperados sobre o schema de exemplo. Os scripts que criam objetos usam o prefixo `TMP_` e removem tudo no fim.

## Consultas

| # | Caso | Explicação | Script |
|---|---|---|---|
| 01 | Último registro de cada grupo: ROW_NUMBER, KEEP DENSE_RANK, OUTER APPLY, NOT EXISTS | [md](01-ultimo-registro-por-grupo.md) | [sql](01-ultimo-registro-por-grupo.sql) |
| 02 | Acumulado mensal, mês anterior, mesmo mês do ano anterior, média móvel | [md](02-acumulado-mensal.md) | [sql](02-acumulado-mensal.sql) |
| 03 | Ranking com empate: ROW_NUMBER × RANK × DENSE_RANK, por período, NTILE | [md](03-ranking-com-empate.md) | [sql](03-ranking-com-empate.sql) |
| 04 | Curva ABC de produtos | [md](04-curva-abc.md) | [sql](04-curva-abc.sql) |
| 05 | Anti-join: clientes sem compra, clientes perdidos, a armadilha do NOT IN | [md](05-anti-join.md) | [sql](05-anti-join.sql) |
| 08 | Calendário: dias sem movimento, grade semanal, dias úteis e prazo | [md](08-calendario.md) | [sql](08-calendario.sql) |
| 12 | Comparar duas tabelas: MINUS, UNION ALL + GROUP BY, FULL OUTER JOIN, impressão digital | [md](12-comparar-tabelas.md) | [sql](12-comparar-tabelas.sql) |
| 13 | Quebrar texto delimitado em linhas e juntar linhas em texto | [md](13-texto-delimitado.md) | [sql](13-texto-delimitado.sql) |

## Processos e PL/SQL

| # | Caso | Explicação | Script |
|---|---|---|---|
| 06 | Auditoria de alterações com trigger e tabela de histórico | [md](06-auditoria-com-trigger.md) | [sql](06-auditoria-com-trigger.sql) |
| 07 | Carga incremental com MERGE: só o que mudou, inativação, idempotência | [md](07-carga-incremental-merge.md) | [sql](07-carga-incremental-merge.sql) |
| 09 | Validação de CPF e CNPJ (inclusive alfanumérico), formatação e geração | [md](09-cpf-cnpj.md) | [sql](09-cpf-cnpj.sql) |
| 10 | Exportação para CSV: function genérica com DBMS_SQL, SPOOL e UTL_FILE | [md](10-exportar-csv.md) | [sql](10-exportar-csv.sql) |
| 11 | Processamento em lote: commit por bloco, SAVE EXCEPTIONS, retomada, log autônomo | [md](11-processamento-em-lote.md) | [sql](11-processamento-em-lote.sql) |

Continua em [16 — Mini-projetos](../16-mini-projetos/README.md).
