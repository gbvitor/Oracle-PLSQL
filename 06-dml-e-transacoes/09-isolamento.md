# Níveis de isolamento

## O que o Oracle oferece

| Nível | Fotografia dos dados | Uso |
|---|---|---|
| `READ COMMITTED` (padrão) | Início de **cada comando** | Quase tudo |
| `SERIALIZABLE` | Início da **transação** | Transações que leem e escrevem e precisam de uma visão estável do começo ao fim |
| `READ ONLY` | Início da transação, sem permitir alteração | Relatórios com várias consultas que precisam bater entre si |

O padrão SQL define também `READ UNCOMMITTED` e `REPEATABLE READ`. O Oracle não oferece leitura de dados não confirmados (não há "dirty read"), e o `SERIALIZABLE` cobre o que o `REPEATABLE READ` garantiria.

```sql
-- primeiro comando da transação
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- idem, para uma transação só de leitura
SET TRANSACTION READ ONLY;

-- para todas as transações da sessão
ALTER SESSION SET ISOLATION_LEVEL = SERIALIZABLE;
```

`SET TRANSACTION` precisa ser o **primeiro** comando da transação (ORA-01453 se não for).

## READ COMMITTED: o que pode acontecer

Dois `SELECT` na mesma transação podem ver dados diferentes, se outra sessão confirmou algo entre eles (leitura não repetível). Um relatório com uma consulta de totais e outra de detalhes pode sair inconsistente: o total não bate com a soma dos detalhes.

Para isso: `SET TRANSACTION READ ONLY` no início do relatório, ou uma consulta só, ou Flashback Query com o mesmo SCN nas duas.

## SERIALIZABLE: ORA-08177

Numa transação serializável, se a sessão tenta alterar uma linha que **outra transação alterou e confirmou depois do início da sua**, o Oracle recusa com **ORA-08177** (não é possível serializar o acesso para esta transação). A aplicação precisa tratar esse erro desfazendo e repetindo a transação.

## READ ONLY

Não permite DML (ORA-01456). Todas as consultas veem os dados como estavam no início, sem custo de bloqueio. Termina com `COMMIT` ou `ROLLBACK`. Consultas muito longas em `READ ONLY` estão sujeitas ao ORA-01555 como qualquer outra (tópico 07).

## Documentação oficial

- [Database Concepts — Data Concurrency and Consistency (Isolation Levels)](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/data-concurrency-and-consistency.html)
- [SQL Language Reference — SET TRANSACTION](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SET-TRANSACTION.html)
