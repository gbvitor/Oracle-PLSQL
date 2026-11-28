# Privilégios: o que eu posso fazer, e por quê

Dois tipos de privilégio (detalhes e comandos `GRANT`/`REVOKE` na seção 13, tópico 04):

- **De sistema**: permite uma ação em geral (`CREATE TABLE`, `CREATE SESSION`, `SELECT ANY TABLE`).
- **De objeto**: permite uma ação num objeto específico (`SELECT ON vendas.pedidos`, `EXECUTE ON pkg_api`).

Os dois podem ser recebidos **diretamente** ou **por meio de uma role**. A diferença importa: privilégio via role não vale dentro de procedure `AUTHID DEFINER` (seção 09, tópico 14).

## As visões

| Visão | Mostra |
|---|---|
| `USER_SYS_PRIVS` | Privilégios de sistema recebidos **diretamente** |
| `USER_ROLE_PRIVS` | Roles recebidas diretamente, e se são `DEFAULT_ROLE` (ativas ao conectar) |
| `ROLE_SYS_PRIVS`, `ROLE_TAB_PRIVS`, `ROLE_ROLE_PRIVS` | O que cada role **ativa** na sessão concede |
| `USER_TAB_PRIVS` | Privilégios de objeto em que você é dono, quem concedeu ou quem recebeu |
| `USER_TAB_PRIVS_MADE`, `USER_TAB_PRIVS_RECD` | Só os que você concedeu, só os que você recebeu |
| `USER_COL_PRIVS` | Privilégios por coluna (`UPDATE (coluna)`) |
| `SESSION_PRIVS` | **Todos** os privilégios de sistema efetivos agora (diretos + roles ativas) |
| `SESSION_ROLES` | Todas as roles ativas agora, inclusive as recebidas por outras roles |
| `USER_TS_QUOTAS` | Cota em cada tablespace (`MAX_BYTES = -1` = ilimitada) |

`DBA_SYS_PRIVS`, `DBA_ROLE_PRIVS`, `DBA_TAB_PRIVS` trazem o mesmo para todos os usuários (o DBA usa para responder "quem pode alterar esta tabela?").

## Roteiro: "por que não consigo acessar a tabela X?"

1. **O objeto existe e com esse nome?** `ALL_OBJECTS WHERE object_name = 'X'`. Se não aparece, ou não existe ou você não tem nenhum privilégio nele (ALL_ só mostra o que você pode acessar).
2. **Está no schema que você imagina?** Sem prefixo, o nome é procurado no schema atual, depois em sinônimos privados e públicos. Use `dono.tabela` ou confira `ALL_SYNONYMS`.
3. **Que privilégio você tem nele?** `ALL_TAB_PRIVS WHERE table_name = 'X'` (diretos e para PUBLIC) e `ROLE_TAB_PRIVS` (por role).
4. **Funciona no editor e não na procedure?** É privilégio via role; peça o grant direto.
5. **Privilégio de sistema `ANY`?** `SESSION_PRIVS` mostra se você tem `SELECT ANY TABLE`, que dispensa grant por objeto.

Mensagens típicas: `ORA-00942` (tabela ou view não existe, também usada quando existe mas você não pode ver), `ORA-01031` (privilégios insuficientes: você vê, mas não pode fazer aquela operação), `ORA-01950` (sem cota no tablespace).

## Documentação oficial

- [Database Reference — USER_SYS_PRIVS](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/USER_SYS_PRIVS.html)
- [Database Reference — ALL_TAB_PRIVS](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/ALL_TAB_PRIVS.html)
- [Database Reference — SESSION_PRIVS](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/SESSION_PRIVS.html)
- [Database Security Guide — Configuring Privilege and Role Authorization](https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/configuring-privilege-and-role-authorization.html)
