# Privilégios de sistema e de objeto, roles, GRANT e REVOKE

Como consultar os privilégios que você tem está na seção 10 (tópico 08). Este tópico trata de conceder e revogar.

## Dois tipos

| Tipo | Exemplos | Concedido com |
|---|---|---|
| **De sistema**: uma ação em geral | `CREATE SESSION`, `CREATE TABLE`, `CREATE PROCEDURE`, `SELECT ANY TABLE`, `ALTER SYSTEM` | `GRANT CREATE TABLE TO vendas;` |
| **De objeto**: uma ação num objeto | `SELECT`, `INSERT`, `UPDATE (coluna)`, `DELETE`, `EXECUTE`, `REFERENCES`, `READ` `[12c+]` | `GRANT SELECT ON vendas.pedidos TO relatorio;` |

- O dono de um objeto tem todos os privilégios sobre ele; não precisa de grant.
- Privilégios `ANY` (`SELECT ANY TABLE`, `DROP ANY TABLE`) valem para objetos de **todos** os schemas. São quase sempre amplos demais para uma aplicação.
- `READ` `[12c+]` permite consultar, mas não `SELECT ... FOR UPDATE` (não trava linhas). É a escolha para usuários de relatório.
- `[23ai+]` Privilégio de schema: `GRANT SELECT ANY TABLE ON SCHEMA vendas TO relatorio;` vale para todas as tabelas de `vendas`, inclusive as criadas depois, sem dar acesso aos outros schemas.

## WITH ADMIN OPTION e WITH GRANT OPTION

| | `WITH ADMIN OPTION` | `WITH GRANT OPTION` |
|---|---|---|
| Vale para | Privilégio de sistema e role | Privilégio de objeto |
| Quem recebe pode | Conceder a outros **e revogar de qualquer um** | Conceder a outros |
| Ao revogar de quem recebeu | Os grants que ele fez **continuam** | Os grants que ele fez **caem junto** (em cascata) |

## Roles

Role é um conjunto de privilégios com nome. Concede-se a role ao usuário, e mudanças na role valem para todos que a têm.

```sql
CREATE ROLE leitura_vendas;
GRANT SELECT ON vendas.pedidos  TO leitura_vendas;
GRANT SELECT ON vendas.clientes TO leitura_vendas;
GRANT leitura_vendas TO ana, bruno;
```

- **Roles padrão** (`DEFAULT ROLE`) são ativadas no login. Outras são ativadas com `SET ROLE`. Role protegida por senha (`IDENTIFIED BY`) ou por package (`IDENTIFIED USING pkg`) só é ativada por quem sabe a senha ou pela package: forma de liberar privilégios só dentro da aplicação.
- **Roles não valem dentro de rotinas armazenadas `AUTHID DEFINER`** (seção 09, tópico 14). Para o código do schema da aplicação, grants diretos.
- Roles predefinidas: `CONNECT` (só `CREATE SESSION` hoje), `RESOURCE` (criar tabelas, procedures, tipos...; desde o 12c sem `UNLIMITED TABLESPACE`), `DBA` (tudo: nunca para aplicação), `SELECT_CATALOG_ROLE`, `DB_DEVELOPER_ROLE` `[23ai+]`.

## PUBLIC

`GRANT ... TO PUBLIC` dá o privilégio a **todos os usuários**, presentes e futuros. Usar com muito critério: auditorias de segurança procuram primeiro os grants para PUBLIC.

## Menor privilégio, na prática

1. Um usuário dono dos objetos (de preferência sem login, `NO AUTHENTICATION`, tópico 03).
2. Usuários de aplicação com `EXECUTE` nas packages de API e, quando necessário, `SELECT`/`INSERT`/`UPDATE` em tabelas específicas, via role.
3. Usuário de relatório com `READ` nas tabelas ou views necessárias.
4. Nenhum `ANY`, nenhum `DBA`, nenhum grant para PUBLIC em objeto de aplicação.

**Privilege analysis** (`DBMS_PRIVILEGE_CAPTURE`, Enterprise Edition `[12c+]`) registra durante um período quais privilégios um usuário ou role realmente usou, para retirar o resto com segurança.

## Documentação oficial

- [SQL Language Reference — GRANT](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/GRANT.html)
- [SQL Language Reference — REVOKE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/REVOKE.html)
- [Database Security Guide — Configuring Privilege and Role Authorization](https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/configuring-privilege-and-role-authorization.html)
- [Database Security Guide — Performing Privilege Analysis](https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/performing-privilege-analysis-find-privilege-use.html)
