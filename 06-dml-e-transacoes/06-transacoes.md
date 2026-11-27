# Transações: COMMIT, ROLLBACK e SAVEPOINT

## O que é uma transação

Um conjunto de alterações que o banco trata como **uma unidade**: ou todas são confirmadas, ou nenhuma. No Oracle, a transação começa sozinha no primeiro comando DML (ou `SELECT ... FOR UPDATE`) e termina com:

| Fim | Efeito |
|---|---|
| `COMMIT` | Confirma tudo; as alterações ficam permanentes e visíveis para as outras sessões |
| `ROLLBACK` | Desfaz tudo desde o início da transação |
| Qualquer DDL (`CREATE`, `ALTER`, `DROP`, `TRUNCATE`, `GRANT`...) | Commit implícito antes e depois (seção 01, tópico 10) |
| Fim normal da sessão | Depende da ferramenta (abaixo) |
| Queda da sessão ou do servidor | Rollback |

Não existe `BEGIN TRANSACTION` no Oracle. `SET TRANSACTION` existe, mas serve para definir características da transação (tópico 09), não para iniciá-la.

## SAVEPOINT

Marca um ponto dentro da transação para onde é possível voltar sem desfazer tudo:

```sql
-- passo 1
INSERT ...;
SAVEPOINT antes_itens;

-- passo 2
INSERT ...;

-- desfaz só o passo 2
ROLLBACK TO antes_itens;

-- confirma o passo 1
COMMIT;
```

- `ROLLBACK TO` **não encerra** a transação; ela continua aberta.
- Savepoints posteriores ao ponto de retorno são descartados.
- Usar o mesmo nome de novo move o savepoint.

## Atomicidade por comando

Se um comando falha, o Oracle desfaz **só aquele comando**, não a transação inteira. As alterações anteriores continuam pendentes, esperando `COMMIT` ou `ROLLBACK`. Por isso, num script com `INSERT` que dá erro no meio, as linhas inseridas antes do erro ainda estão lá; quem decide o que fazer é o script (`WHENEVER SQLERROR EXIT ROLLBACK` no SQL*Plus, tratamento de exceção em PL/SQL).

## Fim da sessão nas ferramentas

| Ferramenta | Ao sair normalmente |
|---|---|
| SQL*Plus / SQLcl | **Commit** por padrão (`SET EXITCOMMIT ON`). `EXIT ROLLBACK` ou `SET EXITCOMMIT OFF` muda |
| SQL Developer, DataGrip, DBeaver | Pergunta, ou segue a configuração de auto-commit |
| Aplicações (JDBC etc.) | Auto-commit costuma vir **ligado** por padrão no driver; cada comando é uma transação |

Ferramenta com auto-commit ligado faz cada `UPDATE` ser confirmado na hora. Ferramenta com auto-commit desligado e uma aba esquecida aberta segura bloqueios por horas. Conheça a configuração da que você usa.

## Quando confirmar

- **Ao fim de uma unidade de negócio** (o pedido com todos os itens), não a cada linha.
- **Não fazer commit dentro de laço linha a linha** "para não estourar o undo": aumenta o tempo total, pode causar ORA-01555 em consultas longas e deixa o processo pela metade se falhar no meio. Para volumes grandes, prefira um comando único ou lotes grandes com controle de reinício (seção 15).

## Documentação oficial

- [Database Concepts — Transactions](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/transactions.html)
- [SQL Language Reference — SAVEPOINT](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SAVEPOINT.html)
