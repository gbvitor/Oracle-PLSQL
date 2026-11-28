# 13 — Administração

O básico de administração que um desenvolvedor precisa saber para não depender do DBA em toda tarefa.

A maior parte das consultas roda como o usuário de estudo, com a `SELECT_CATALOG_ROLE` concedida em `00-ambiente`. Comandos que exigem privilégio de administrador estão marcados com **[DBA]** (ou **[AUDIT_ADMIN]**) e separados em partes próprias; os que só fazem sentido com várias sessões indicam em qual rodar cada passo. No FreeSQL, só as consultas funcionam.

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 01 | Arquitetura: instância, SGA, PGA, processos, arquivos, redo e undo | [md](01-arquitetura.md) | [sql](01-arquitetura.sql) |
| 02 | Multitenant: CDB, PDB, conexão, usuários comuns e locais | [md](02-multitenant.md) | [sql](02-multitenant.sql) |
| 03 | Usuários, perfis e senhas; schema sem login; situação da conta | [md](03-usuarios-e-perfis.md) | [sql](03-usuarios-e-perfis.sql) |
| 04 | Privilégios de sistema e de objeto, roles, READ, GRANT OPTION e ADMIN OPTION | [md](04-privilegios-e-roles.md) | [sql](04-privilegios-e-roles.sql) |
| 05 | Tablespaces e cotas; uso de espaço; espaço que não volta | [md](05-tablespaces-e-cotas.md) | [sql](05-tablespaces-e-cotas.sql) |
| 06 | Sessões: identificar, monitorar, cancelar e encerrar | [md](06-sessoes.md) | [sql](06-sessoes.sql) |
| 07 | Locks e bloqueios: cadeia de espera, bloqueadora inativa, linha exata | [md](07-locks-e-bloqueios.md) | [sql](07-locks-e-bloqueios.sql) |
| 08 | Jobs: DBMS_SCHEDULER, calendário, falhas, acompanhamento (e DBMS_JOB `[legado]`) | [md](08-dbms-scheduler.md) | [sql](08-dbms-scheduler.sql) |
| 09 | Flashback: versões, FLASHBACK TABLE, lixeira, banco | [md](09-flashback.md) | [sql](09-flashback.sql) |
| 10 | Data Pump: expdp, impdp e DBMS_DATAPUMP | [md](10-data-pump.md) | [sql](10-data-pump.sql) |
| 11 | Parâmetros de inicialização e NLS: camadas, character set, ordenação | [md](11-parametros-e-nls.md) | [sql](11-parametros-e-nls.sql) |
| 12 | Auditoria unificada e fine-grained auditing | [md](12-auditoria.md) | [sql](12-auditoria.sql) |

Continua em [14 — Outros SGBDs](../14-sgbds/README.md).
