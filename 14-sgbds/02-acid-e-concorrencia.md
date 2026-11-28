# Propriedades ACID e controle de concorrência (MVCC e locks)

## ACID

| Propriedade | Garante | Como o Oracle implementa |
|---|---|---|
| **Atomicidade** | A transação acontece por inteiro ou nada acontece | Undo: o ROLLBACK desfaz; falha no meio desfaz a instrução (seção 06, tópico 06) |
| **Consistência** | A transação leva o banco de um estado válido a outro | Constraints, tipos, triggers |
| **Isolamento** | Transações simultâneas não enxergam o trabalho pela metade umas das outras | Consistência de leitura com undo (seção 06, tópico 07) e locks de linha |
| **Durabilidade** | O que recebeu COMMIT sobrevive a uma queda | Redo log gravado em disco no COMMIT |

## Fenômenos que o isolamento evita

| Fenômeno | O que acontece |
|---|---|
| **Leitura suja** (*dirty read*) | Ler dado alterado por outra transação que ainda não confirmou (e pode desfazer) |
| **Leitura não repetível** | Ler a mesma linha duas vezes na transação e ver valores diferentes, porque outra confirmou no meio |
| **Fantasma** (*phantom*) | Repetir uma consulta e aparecerem linhas novas que atendem ao filtro |
| **Anomalia de serialização** | O resultado de transações simultâneas não corresponde a nenhuma ordem em sequência delas (*write skew*) |

Os níveis do padrão SQL: `READ UNCOMMITTED`, `READ COMMITTED`, `REPEATABLE READ`, `SERIALIZABLE`, cada um evitando mais fenômenos.

## Duas famílias de solução

**Locks (pessimista)**: quem lê trava a linha para leitura; quem quer gravar espera. Leitores bloqueiam escritores e vice-versa.

**MVCC** (*multiversion concurrency control*): cada leitura enxerga uma "foto" consistente dos dados; quem grava cria uma versão nova da linha. **Leitores não bloqueiam escritores, escritores não bloqueiam leitores.** Dois escritores na mesma linha ainda se esperam.

## Como cada SGBD faz

| | Oracle | PostgreSQL | SQL Server | MySQL (InnoDB) |
|---|---|---|---|---|
| Modelo padrão | MVCC | MVCC | **Locks** (leitura com lock compartilhado) | MVCC |
| Onde ficam as versões antigas | Undo tablespace | **Na própria tabela** (linhas mortas, limpas pelo `VACUUM`) | `tempdb` (quando o snapshot está ligado) | Undo log |
| Isolamento padrão | `READ COMMITTED` | `READ COMMITTED` | `READ COMMITTED` | **`REPEATABLE READ`** |
| `READ UNCOMMITTED` | Não existe | Aceito, mas age como READ COMMITTED | Existe (`NOLOCK`) | Existe |
| `SERIALIZABLE` | Na verdade *snapshot isolation*: pode deixar passar *write skew*; erro ORA-08177 em conflito | Serializável de verdade (SSI), erro de serialização em conflito | Por locks de faixa | Por locks (as leituras viram `LOCK IN SHARE MODE`) |
| Leitura de dado em gravação | Lê a versão confirmada anterior | Lê a versão confirmada anterior | **Espera** o lock, a menos que `READ_COMMITTED_SNAPSHOT` esteja ligado | Lê a versão anterior |

Consequências práticas:

- **SQL Server**: relatórios pesados travando a operação (e vice-versa) é problema comum, e `WITH (NOLOCK)` espalhado pelo código é a "solução" que lê dado sujo. O caminho certo é ligar `READ_COMMITTED_SNAPSHOT` no banco (no Azure SQL Database já vem ligado).
- **PostgreSQL**: tabelas com muito UPDATE e DELETE acumulam linhas mortas; o `autovacuum` precisa dar conta, ou a tabela incha e as consultas pioram. Transação aberta há horas impede a limpeza.
- **MySQL**: em `REPEATABLE READ`, InnoDB usa *gap locks* e *next-key locks* em buscas por faixa: um `UPDATE ... WHERE data > x` pode travar inserções em faixas que nem existem ainda, causando deadlocks que não aconteceriam no Oracle.
- **Oracle**: consulta longa pode falhar com ORA-01555 se o undo necessário à "foto" for reaproveitado.

## Documentação

- [Oracle Database Concepts — Data Concurrency and Consistency](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/data-concurrency-and-consistency.html)
- [PostgreSQL — Concurrency Control](https://www.postgresql.org/docs/current/mvcc.html)
- [SQL Server — Transaction locking and row versioning guide](https://learn.microsoft.com/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide)
- [MySQL — InnoDB Locking and Transaction Model](https://dev.mysql.com/doc/refman/8.4/en/innodb-locking-transaction-model.html)
