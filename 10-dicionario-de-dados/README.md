# 10 — Dicionário de dados

Como descobrir a estrutura de um banco que você não conhece: tabelas, colunas, constraints, dependências e código-fonte, só com consultas.

Os valores esperados nos scripts são os do schema de exemplo recém-instalado (7 tabelas, 18 índices, nenhum código). Objetos criados para os exemplos usam o prefixo `tmp_` e são removidos no fim.

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 01 | Prefixos USER_, ALL_, DBA_ e CDB_; DICTIONARY; nomes em maiúsculas; colunas LONG | [md](01-prefixos-e-dictionary.md) | [sql](01-prefixos-e-dictionary.sql) |
| 02 | Tabelas e colunas: USER_TABLES, USER_TAB_COLUMNS, comentários, colunas virtuais | [md](02-tabelas-e-colunas.md) | [sql](02-tabelas-e-colunas.sql) |
| 03 | Constraints e chaves: mapa de FKs, quem referencia, FK sem índice, CHECKs | [md](03-constraints-e-chaves.md) | [sql](03-constraints-e-chaves.sql) |
| 04 | Índices: colunas, expressões, estatísticas, redundância, UNUSABLE, tamanho | [md](04-indices.md) | [sql](04-indices.sql) |
| 05 | Objetos e código: USER_OBJECTS, USER_SOURCE, USER_PROCEDURES, USER_ARGUMENTS | [md](05-objetos-e-codigo.md) | [sql](05-objetos-e-codigo.sql) |
| 06 | Dependências: quem usa esta tabela, árvore e pontos cegos | [md](06-dependencias.md) | [sql](06-dependencias.sql) |
| 07 | Triggers: USER_TRIGGERS, colunas, corpo e DDL | [md](07-triggers.md) | [sql](07-triggers.sql) |
| 08 | Privilégios: de sistema, de objeto, por role, efetivos; "por que não consigo acessar" | [md](08-privilegios.md) | [sql](08-privilegios.sql) |
| 09 | Visões dinâmicas V$: sessões, SQL em memória, bloqueios, licenciamento | [md](09-visoes-v.md) | [sql](09-visoes-v.sql) |
| 10 | Roteiro de descoberta de um schema desconhecido | [md](10-roteiro-de-descoberta.md) | [sql](10-roteiro-de-descoberta.sql) |

Continua em [11 — Performance](../11-performance/README.md).
