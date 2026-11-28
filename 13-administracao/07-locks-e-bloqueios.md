# Locks e bloqueios: diagnóstico

Como os locks funcionam (linha, tabela, deadlock, FK sem índice) está na seção 06 (tópico 08); as visões, na seção 10 (tópico 09). Aqui, o roteiro de diagnóstico quando alguém liga dizendo "a tela travou".

## O roteiro

1. **Quem está esperando?** `V$SESSION` com `BLOCKING_SESSION` preenchido. O `EVENT` diz o tipo de espera:

   | Evento | Causa |
   |---|---|
   | `enq: TX - row lock contention` | Linha travada por outra transação (UPDATE/DELETE/SELECT FOR UPDATE não confirmados) |
   | `enq: TM - contention` | Lock de tabela: quase sempre FK sem índice na tabela filha, com DELETE/UPDATE no pai |
   | `enq: TX - index contention`, `allocate ITL entry` | Concorrência intensa nos mesmos blocos |
   | `library cache lock` / `library cache pin` | Alguém recompilando um objeto que outra sessão está executando, ou o contrário |

2. **Quem está no topo da cadeia?** A sessão A bloqueia B, que bloqueia C. `FINAL_BLOCKING_SESSION` `[11gR2+]` aponta direto para A; uma consulta hierárquica mostra a árvore inteira.
3. **O que a bloqueadora está fazendo?** Na maioria dos casos: **nada**. `STATUS = 'INACTIVE'` com `LAST_CALL_ET` alto: uma transação aberta e esquecida (alguém que fez UPDATE no SQL Developer e foi almoçar, ou uma aplicação que não faz COMMIT num caminho de erro). O SQL que causou o lock **já terminou** e não aparece em `SQL_ID`; `PREV_SQL_ID` às vezes ajuda.
4. **Que objeto e que linha?** `V$LOCKED_OBJECT` dá o objeto; `ROW_WAIT_OBJ#`, `ROW_WAIT_FILE#`, `ROW_WAIT_BLOCK#` e `ROW_WAIT_ROW#` da sessão que espera dão o **ROWID** exato (`DBMS_ROWID.ROWID_CREATE`).
5. **Resolver**: falar com o dono da sessão (COMMIT ou ROLLBACK) é sempre melhor; encerrar a sessão (tópico 06) desfaz a transação dela.

## DDL e locks

DDL numa tabela com transação aberta falha na hora com ORA-00054 (*resource busy and acquire with NOWAIT specified or timeout expired*). `ALTER SESSION SET DDL_LOCK_TIMEOUT = 30` faz o DDL esperar até 30 segundos em vez de falhar: útil em deploy com o sistema no ar.

## Deadlock

O Oracle detecta e resolve sozinho em poucos segundos: uma das instruções recebe ORA-00060 e é desfeita (a transação continua; quem recebeu o erro decide). O alert log registra e um trace guarda o grafo de espera com as duas instruções. Deadlock frequente é erro de desenho: duas rotinas que atualizam as mesmas tabelas em ordens diferentes, ou FK sem índice.

## Prevenção

- Transações curtas; COMMIT logo depois do trabalho, nunca esperando o usuário.
- Índice em toda FK cuja tabela pai sofre DELETE ou UPDATE de chave (seção 10, tópico 03).
- `SELECT ... FOR UPDATE NOWAIT` ou `WAIT n` em telas de edição, para avisar o usuário em vez de travar (seção 02, tópico 11).
- `SKIP LOCKED` em filas de processamento.
- Mesma ordem de atualização das tabelas em todas as rotinas.

## Documentação oficial

- [Database Concepts — Data Concurrency and Consistency: Locks](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/data-concurrency-and-consistency.html)
- [Database Reference — V$SESSION (BLOCKING_SESSION, FINAL_BLOCKING_SESSION)](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/V-SESSION.html)
