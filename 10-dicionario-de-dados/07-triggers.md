# Triggers no dicionário: USER_TRIGGERS e o corpo do trigger

Trigger é lógica escondida: quem lê um `INSERT` não vê o que dispara junto. Antes de mexer numa tabela de um sistema que você não conhece, liste os triggers dela. Como os triggers funcionam está na seção 09 (tópicos 04 a 06).

## As visões

| Visão | Uma linha por | Colunas mais usadas |
|---|---|---|
| `USER_TRIGGERS` | Trigger | `TRIGGER_NAME`, `TRIGGER_TYPE`, `TRIGGERING_EVENT`, `TABLE_NAME`, `BASE_OBJECT_TYPE`, `WHEN_CLAUSE`, `STATUS`, `DESCRIPTION`, `TRIGGER_BODY` (LONG) |
| `USER_TRIGGER_COLS` | Coluna citada no trigger | Colunas do `UPDATE OF` e as usadas com `:NEW`/`:OLD` |
| `USER_TRIGGER_ORDERING` | Relação `FOLLOWS`/`PRECEDES` | Ordem declarada entre triggers |
| `USER_SOURCE` (`TYPE = 'TRIGGER'`) | Linha do código | Pesquisa de texto, igual às procedures |

## Lendo TRIGGER_TYPE e BASE_OBJECT_TYPE

| `TRIGGER_TYPE` | Significa |
|---|---|
| `BEFORE EACH ROW`, `AFTER EACH ROW` | Trigger de linha |
| `BEFORE STATEMENT`, `AFTER STATEMENT` | Trigger de instrução |
| `INSTEAD OF` | Em view |
| `COMPOUND` | Compound trigger |
| `BEFORE EVENT`, `AFTER EVENT` | Trigger de sistema (DDL, LOGON...) |

`BASE_OBJECT_TYPE` diz onde o trigger está pendurado: `TABLE`, `VIEW`, `SCHEMA` ou `DATABASE`. Os de `SCHEMA` e `DATABASE` não têm `TABLE_NAME` e afetam todo DDL ou toda conexão: são os primeiros a conferir quando "o CREATE TABLE está falhando sem motivo" ou "o login ficou lento".

## O corpo

- `TRIGGER_BODY` é LONG: aparece na consulta (com `SET LONG` alto no SQL*Plus), mas não pode ser filtrado com `LIKE`.
- Para pesquisar dentro do código: `USER_SOURCE WHERE type = 'TRIGGER'`.
- Para o DDL completo, com cabeçalho, `WHEN` e o estado (`ALTER TRIGGER ... ENABLE`): `DBMS_METADATA.GET_DDL('TRIGGER', nome)`.

## Documentação oficial

- [Database Reference — ALL_TRIGGERS](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/ALL_TRIGGERS.html)
- [Database Reference — ALL_TRIGGER_COLS](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/ALL_TRIGGER_COLS.html)
