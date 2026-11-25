# 01 — Fundamentos

Conceitos que o resto do repositório pressupõe: como o Oracle organiza dados, quais tipos existem e como o NULL se comporta.

## Tópicos

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 01 | Modelo relacional: tabela, chaves, integridade, normalização | [md](01-modelo-relacional.md) | [sql](01-modelo-relacional.sql) |
| 02 | Instância, banco, schema e usuário (CDB/PDB) | [md](02-instancia-banco-schema.md) | [sql](02-instancia-banco-schema.sql) |
| 03 | Tipos de dados | [md](03-tipos-de-dados.md) | [sql](03-tipos-de-dados.sql) |
| 04 | NULL e a lógica de três valores | [md](04-null.md) | [sql](04-null.sql) |
| 05 | DUAL e consultas sem tabela | [md](05-dual.md) | [sql](05-dual.sql) |
| 06 | Pseudocolunas: ROWNUM, ROWID, LEVEL, ORA_ROWSCN | [md](06-pseudocolunas.md) | [sql](06-pseudocolunas.sql) |
| 07 | Identificadores: maiúsculas, aspas, palavras reservadas, limites | [md](07-identificadores.md) | [sql](07-identificadores.sql) |
| 08 | Comentários em SQL, PL/SQL e no dicionário | [md](08-comentarios.md) | — |
| 09 | Ordem lógica de execução do SELECT | [md](09-ordem-logica-do-select.md) | [sql](09-ordem-logica-do-select.sql) |
| 10 | Categorias de comando e o commit implícito do DDL | [md](10-categorias-de-comando.md) | [sql](10-categorias-de-comando.sql) |

## Como usar os scripts

Todos rodam sobre o schema de exemplo (`00-ambiente`) e podem ser executados em qualquer ordem. Os que criam objetos usam o prefixo `tmp_` e os removem no fim. Comandos que terminam em erro de propósito têm o código ORA- esperado no comentário da linha de cima.
