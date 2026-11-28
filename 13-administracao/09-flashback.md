# Flashback: versões, tabela, DROP e banco

A consulta de dados no passado (`AS OF TIMESTAMP` / `AS OF SCN`) está na seção 02 (tópico 13). Este tópico trata do resto da família flashback: ver o histórico de uma linha, voltar uma tabela inteira, recuperar uma tabela excluída e, no nível do DBA, voltar o banco.

## Quadro geral

| Recurso | Volta | Baseado em | Quem |
|---|---|---|---|
| Flashback Query (`AS OF`) | Uma consulta, no passado | Undo | Dono da tabela ou privilégio `FLASHBACK` |
| Flashback Version Query (`VERSIONS BETWEEN`) | Todas as versões de cada linha num intervalo | Undo | Idem |
| Flashback Transaction Query | O SQL que desfaz uma transação | Undo + supplemental logging | `SELECT ANY TRANSACTION` (DBA) |
| **Flashback Table `TO SCN/TIMESTAMP`** | A tabela inteira a um ponto anterior | Undo | Dono, com `ROW MOVEMENT` |
| **Flashback Table `TO BEFORE DROP`** | Uma tabela excluída | Lixeira (*recycle bin*) | Dono |
| Flashback Database | O banco inteiro | Flashback logs | DBA |
| Flashback Data Archive (Flashback Time Travel) | Histórico de longo prazo de tabelas escolhidas | Tabelas de histórico | DBA configura |

## Versões de uma linha

```sql
SELECT versions_startscn, versions_endscn, versions_operation, versions_xid, id_cliente, limite_credito
  FROM clientes VERSIONS BETWEEN TIMESTAMP SYSTIMESTAMP - INTERVAL '1' HOUR AND SYSTIMESTAMP
 WHERE id_cliente = 1;
```

| Pseudocoluna | Significa |
|---|---|
| `VERSIONS_OPERATION` | `I`, `U` ou `D`: a operação que criou esta versão |
| `VERSIONS_STARTSCN` / `_STARTTIME` | Quando a versão passou a valer (NULL = já existia antes do intervalo) |
| `VERSIONS_ENDSCN` / `_ENDTIME` | Quando deixou de valer (NULL = é a versão atual) |
| `VERSIONS_XID` | A transação que criou a versão |

Responde "quem mudou este valor e quando?" sem trigger de auditoria, dentro do alcance do undo.

## Voltar a tabela

```sql
ALTER TABLE clientes ENABLE ROW MOVEMENT;
FLASHBACK TABLE clientes TO TIMESTAMP SYSTIMESTAMP - INTERVAL '15' MINUTE;
```

- Exige `ROW MOVEMENT` (as linhas podem mudar de ROWID).
- É uma operação DML por baixo (desfaz as mudanças usando o undo) e faz COMMIT. Desfaz **todas** as alterações do período, de todos os usuários, não só as erradas.
- Os triggers ficam desligados durante o flashback, a menos que se use `ENABLE TRIGGERS`.
- Não atravessa DDL que mudou a estrutura da tabela (ORA-01466: a definição da tabela mudou).
- Várias tabelas ligadas por FK: `FLASHBACK TABLE pedidos, itens_pedido TO ...` numa instrução só.

Quando só algumas linhas estão erradas, a cirurgia é melhor que o flashback da tabela: `UPDATE ... SET col = (SELECT col FROM t AS OF ... WHERE ...)` ou `INSERT INTO t SELECT * FROM t AS OF ... WHERE ... ` (seção 02, tópico 13).

## A lixeira

`DROP TABLE` sem `PURGE` move a tabela, com índices, constraints e triggers, para a lixeira (`USER_RECYCLEBIN`, `SHOW RECYCLEBIN`):

```sql
FLASHBACK TABLE pedidos TO BEFORE DROP;
FLASHBACK TABLE pedidos TO BEFORE DROP RENAME TO pedidos_recuperada;
PURGE TABLE pedidos;
PURGE RECYCLEBIN;
```

Os índices voltam com o nome interno (`BIN$...`); renomeie depois. A lixeira é esvaziada sozinha quando o tablespace precisa do espaço: não é backup.

## O alcance

Tudo o que se baseia em undo depende de o undo antigo ainda existir: `UNDO_RETENTION` (padrão 900 segundos, 15 minutos) é o mínimo que o Oracle **tenta** guardar, se o tablespace de undo tiver espaço; `RETENTION GUARANTEE` no tablespace torna obrigatório. Além disso, ORA-01555 ou ORA-08180. Para horas ou dias, Flashback Database (pontos de restauração, `CREATE RESTORE POINT antes_deploy GUARANTEE FLASHBACK DATABASE`) ou Flashback Data Archive.

## Documentação oficial

- [Database Development Guide — Using Oracle Flashback Technology](https://docs.oracle.com/en/database/oracle/oracle-database/19/adfns/flashback.html)
- [SQL Language Reference — FLASHBACK TABLE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/FLASHBACK-TABLE.html)
- [Backup and Recovery User's Guide — Using Flashback Database and Restore Points](https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/using-flasback-database-restore-points.html)
