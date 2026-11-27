# DML error logging (LOG ERRORS)

## O problema

Um `INSERT ... SELECT` de 100 mil linhas que encontra uma linha inválida na posição 99.999 falha **inteiro**: o comando é desfeito e nenhuma linha entra (tópico 06). A alternativa clássica, um laço linha a linha com tratamento de exceção, é muito mais lenta.

Com `LOG ERRORS`, o comando continua: as linhas válidas são gravadas, e as inválidas vão para uma **tabela de erros**, com o código e a mensagem de cada uma.

## Como usar

```sql
-- 1. Criar a tabela de erros (uma vez). O nome padrão é ERR$_ + nome da tabela.
EXEC DBMS_ERRLOG.CREATE_ERROR_LOG('CLIENTES')

-- 2. Usar no DML
INSERT INTO clientes (...)
SELECT ... FROM carga_clientes
LOG ERRORS INTO err$_clientes ('carga 2026-11-27') REJECT LIMIT UNLIMITED;
```

| Parte | Papel |
|---|---|
| `INTO err$_tabela` | Tabela que recebe as linhas rejeitadas |
| `('etiqueta')` | Texto livre gravado em `ORA_ERR_TAG$`, para identificar a execução |
| `REJECT LIMIT n` | Quantos erros tolerar antes de o comando falhar de vez (padrão 0). `UNLIMITED` para não limitar |

A tabela de erros tem as colunas `ORA_ERR_NUMBER$`, `ORA_ERR_MESG$`, `ORA_ERR_ROWID$`, `ORA_ERR_OPTYP$` (I, U, D), `ORA_ERR_TAG$` e uma cópia, em texto, de cada coluna da tabela de destino.

Funciona em `INSERT`, `UPDATE`, `DELETE` e `MERGE`.

## Limitações

- **Não registra** erros de violação de constraint diferida, nem erros de **chave única em carga direta** (`APPEND`) e em `UPDATE`/`MERGE` que violem chave única: nesses casos, o comando falha como sem `LOG ERRORS`.
- Erros que não são de linha (falta de espaço, privilégio) param o comando normalmente.
- As linhas da tabela de erros **não são desfeitas** pelo `ROLLBACK` do comando ou da transação: o Oracle as grava de forma independente (como uma transação autônoma). O comportamento é útil (o registro dos erros sobrevive a uma carga desfeita), mas não está descrito com destaque na documentação; o script deste tópico demonstra.
- A tabela de erros cresce a cada execução. Limpe por etiqueta.

## Documentação oficial

- [SQL Language Reference — INSERT (error_logging_clause)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/INSERT.html)
- [PL/SQL Packages and Types Reference — DBMS_ERRLOG](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_ERRLOG.html)
