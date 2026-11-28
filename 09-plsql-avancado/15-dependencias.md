# Dependências, invalidação e recompilação

Uma view que lê uma tabela, uma procedure que usa a view, uma package que chama a procedure: o Oracle registra cada uma dessas dependências. Quando um objeto muda, os que dependem dele podem ficar **INVALID** e precisar de recompilação.

## Onde ver

| Visão | Mostra |
|---|---|
| `USER_DEPENDENCIES` | Quem depende de quem (`name` depende de `referenced_name`) |
| `USER_OBJECTS.status` | `VALID` ou `INVALID` |
| `USER_ERRORS` | Erros da última compilação |
| `DBA_DEPENDENCIES`, `ALL_DEPENDENCIES` | O mesmo entre schemas |

SQL **dinâmico** não gera dependência: o Oracle não sabe que `EXECUTE IMMEDIATE 'SELECT ... FROM clientes'` usa `clientes`. É mais um motivo para preferir SQL estático (tópico 09), e um ponto cego em análise de impacto.

## O que invalida

Desde o 11g, a dependência é **fina** (fine-grained): o Oracle registra *quais elementos* de um objeto são usados, não só o objeto.

| Mudança | Efeito nos dependentes |
|---|---|
| Acrescentar coluna na tabela | Normalmente nenhum (quem usa colunas explícitas não é afetado) |
| Mudar tipo ou tamanho de coluna usada | INVALID |
| Remover ou renomear coluna usada | INVALID, e a recompilação falha |
| Recompilar só o **corpo** da package | Nenhum: dependentes apontam para a especificação |
| Acrescentar item no fim da especificação | Normalmente nenhum |
| Mudar a assinatura de um item usado da especificação | INVALID |
| `DROP` do objeto | Dependentes INVALID |

`SELECT *` numa view é resolvido na criação: a view guarda a lista de colunas daquele momento. Coluna nova na tabela não aparece na view até ela ser recriada.

## Recompilação

- **Automática**: um objeto INVALID é recompilado na próxima vez que for usado. Se compilar, a chamada segue normalmente; se não, erro (PLS-00905 para PL/SQL, ORA-04063 para view).
- **Manual**: `ALTER PROCEDURE p COMPILE`, `ALTER PACKAGE pkg COMPILE [BODY]`, `ALTER VIEW v COMPILE`.
- **Em lote**: `DBMS_UTILITY.COMPILE_SCHEMA(USER, compile_all => FALSE)` recompila os inválidos do schema na ordem de dependência. O DBA usa `UTL_RECOMP` ou o script `utlrp.sql` para o banco inteiro.

Depois de um deploy, a conferência básica:

```sql
SELECT object_type, object_name FROM user_objects WHERE status = 'INVALID' ORDER BY 1, 2;
```

## Por que isso importa em produção

- Recompilar uma package em uso causa ORA-04068 nas sessões que tinham estado dela (tópico 03) e pode esperar por lock de biblioteca (library cache pin) enquanto alguém a executa.
- Alterar uma tabela muito referenciada pode invalidar centenas de objetos; a primeira chamada de cada um paga a recompilação.
- **Edition-Based Redefinition** `[11gR2+]` permite instalar a versão nova do código ao lado da antiga e trocar sem parar a aplicação. Exige preparação do schema (editions, editioning views).

Análise de impacto antes de alterar: a árvore de dependentes (script, passo 6) e, para SQL dinâmico e código fora do banco, busca textual em `USER_SOURCE` e no repositório da aplicação.

## Documentação oficial

- [Database Development Guide — Schema Object Dependency](https://docs.oracle.com/en/database/oracle/oracle-database/19/adfns/schema-object-dependency.html)
- [PL/SQL Packages and Types Reference — DBMS_UTILITY.COMPILE_SCHEMA](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_UTILITY.html)
- [Database Development Guide — Using Edition-Based Redefinition](https://docs.oracle.com/en/database/oracle/oracle-database/19/adfns/editions.html)
