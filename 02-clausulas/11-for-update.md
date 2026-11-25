# FOR UPDATE

## O que faz

Lê as linhas e já as **bloqueia** para alteração, até o fim da transação (`COMMIT` ou `ROLLBACK`). Outras sessões continuam podendo **ler** essas linhas (veem a versão confirmada), mas não podem alterá-las, apagá-las nem bloqueá-las com outro `FOR UPDATE` enquanto o bloqueio durar.

```sql
SELECT id_pedido, status
  FROM pedidos
 WHERE id_pedido = 1022
   FOR UPDATE;
```

## Para que serve

Evitar a **atualização perdida**. Sem bloqueio, duas sessões leem o mesmo saldo, cada uma calcula o novo valor a partir do que leu, e a segunda gravação apaga a primeira. Com `FOR UPDATE`, a segunda sessão espera a primeira terminar e então lê o valor já atualizado.

## Variações

| Forma | Se a linha já estiver bloqueada |
|---|---|
| `FOR UPDATE` | Espera indefinidamente |
| `FOR UPDATE NOWAIT` | Falha na hora com ORA-00054 |
| `FOR UPDATE WAIT n` | Espera até `n` segundos e falha com ORA-30006 |
| `FOR UPDATE SKIP LOCKED` | Ignora as linhas bloqueadas e devolve só as livres |
| `FOR UPDATE OF tabela.coluna` | Em join, bloqueia só as linhas das tabelas citadas |

**SKIP LOCKED** é o padrão para **fila de processamento** com vários processos em paralelo: cada processo pega os itens que ninguém está tratando, sem esperar e sem pegar o mesmo item duas vezes.

**FOR UPDATE OF** importa em joins. `SELECT ... FROM pedidos p JOIN clientes c ... FOR UPDATE` bloqueia as linhas das duas tabelas; `FOR UPDATE OF p.status` bloqueia só os pedidos. A coluna citada serve apenas para identificar a tabela.

## Bloqueio pessimista e otimista

`FOR UPDATE` é **bloqueio pessimista**: bloqueia ao ler, supondo que haverá conflito. Funciona bem em transações curtas dentro do banco. Em telas em que o usuário lê, pensa e só depois salva, segurar o bloqueio é inviável.

A alternativa é o **bloqueio otimista**: ler sem bloquear e, ao gravar, conferir se a linha mudou desde a leitura (por uma coluna de versão, data de alteração ou `ORA_ROWSCN`). Se mudou, a gravação é recusada e o usuário relê.

```sql
-- Se afetar 0 linhas, alguém alterou o pedido depois da leitura
UPDATE pedidos
   SET status = 'FATURADO', versao = versao + 1
 WHERE id_pedido = :id
   AND versao = :versao_lida;
```

## Restrições

`FOR UPDATE` não pode ser usado com `DISTINCT`, `GROUP BY`, funções de agregação nem operadores de conjunto (ORA-01786): o resultado precisa corresponder a linhas físicas identificáveis.

## Armadilhas

- **SKIP LOCKED com ROWNUM.** `WHERE ROWNUM <= 5 ... FOR UPDATE SKIP LOCKED` pode devolver menos de 5 linhas: o `ROWNUM` é aplicado antes de descobrir quais estão bloqueadas. Em fila, o padrão é abrir um cursor com `SKIP LOCKED` e buscar as primeiras linhas com `FETCH ... LIMIT` em PL/SQL (seção 09).
- **Esquecer o COMMIT.** O bloqueio fica até o fim da sessão, e quem precisar das linhas fica esperando. Ferramentas gráficas com auto-commit desligado são a causa mais comum.
- **Deadlock.** Duas sessões bloqueando as mesmas linhas em ordem inversa. O Oracle detecta e desfaz o comando de uma delas com ORA-00060. Bloqueie sempre na mesma ordem (por exemplo, por chave).

## Documentação oficial

- [SQL Language Reference — SELECT (for_update_clause)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SELECT.html)
- [Database Concepts — Data Concurrency and Consistency](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/data-concurrency-and-consistency.html)
