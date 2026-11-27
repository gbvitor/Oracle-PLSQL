# Locks de linha e de tabela

## Como o Oracle bloqueia

| Lock | Quando | O que impede |
|---|---|---|
| **De linha (TX)** | `INSERT`, `UPDATE`, `DELETE`, `MERGE`, `SELECT ... FOR UPDATE` | Outra sessão alterar ou bloquear **a mesma linha** até o fim da transação |
| **De tabela (TM)** | Junto com todo DML, em modo compartilhado | DDL na tabela (`ALTER`, `DROP`) enquanto houver DML pendente; ORA-00054 para quem tentar |
| **De tabela exclusivo** | `LOCK TABLE ... IN EXCLUSIVE MODE`, carga direta (`APPEND`) | Qualquer DML de outras sessões |

Pontos importantes:

- **Leitura não bloqueia e não é bloqueada** (tópico 07).
- O Oracle **não escala** locks: bloquear um milhão de linhas não vira um lock da tabela inteira. O lock de linha fica no próprio bloco de dados, sem custo de memória por linha.
- Locks são liberados só no `COMMIT` ou `ROLLBACK`. `ROLLBACK TO SAVEPOINT` libera os locks adquiridos depois do savepoint.

## Esperas e deadlock

Uma sessão que tenta alterar uma linha bloqueada **espera** indefinidamente (ou falha na hora, se usou `FOR UPDATE NOWAIT`, seção 02, tópico 11).

**Deadlock**: a sessão A bloqueia a linha 1 e espera a 2; a sessão B bloqueia a 2 e espera a 1. O Oracle detecta em poucos segundos e desfaz **o comando** (não a transação) de uma delas, com **ORA-00060**. A outra continua esperando até a primeira fazer commit ou rollback. Prevenção: alterar as linhas **sempre na mesma ordem** (por exemplo, por chave crescente).

## FK sem índice

Ao apagar uma linha da tabela pai (ou alterar a chave dela), o Oracle precisa garantir que nenhuma sessão insira um filho apontando para ela. Se a coluna da FK na tabela **filha não tem índice**, a única forma é bloquear a **tabela filha inteira** (lock TM em modo compartilhado) durante o comando. Em sistema com muitas transações, isso trava inserções na filha e pode gerar deadlocks difíceis de explicar.

Regra: **toda FK precisa de índice** na coluna da tabela filha, salvo se a tabela pai nunca tiver linhas apagadas nem chave alterada. O schema de exemplo cria esses índices em `02-criar-schema.sql`.

## Diagnóstico

```sql
-- Quem está bloqueado e por quem
SELECT sid, serial#, username, blocking_session, event, seconds_in_wait, sql_id
  FROM v$session
 WHERE blocking_session IS NOT NULL;

-- Objetos com lock e as sessões que os seguram
SELECT o.owner, o.object_name, l.session_id, l.locked_mode
  FROM v$locked_object l
  JOIN dba_objects     o ON o.object_id = l.object_id;
```

Exigem acesso às visões `V$` (`SELECT_CATALOG_ROLE`). Encerrar a sessão bloqueadora (`ALTER SYSTEM KILL SESSION`) é tarefa de DBA e desfaz tudo o que ela tinha pendente (seção 13).

## Documentação oficial

- [Database Concepts — Data Concurrency and Consistency (Overview of Locking Mechanisms)](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/data-concurrency-and-consistency.html)
