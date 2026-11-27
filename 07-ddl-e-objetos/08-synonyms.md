# Synonyms

## O que é

Um synonym é um **apelido** para outro objeto (tabela, view, sequence, procedure, package, outro synonym), que pode estar em outro schema ou em outro banco. Serve para que a aplicação use um nome curto e estável (`clientes`) em vez do nome completo (`vendas.clientes` ou `clientes@filial`).

```sql
-- privado: só no schema de quem cria
CREATE [OR REPLACE] SYNONYM clientes FOR vendas.clientes;
-- público: vale para todos os usuários
CREATE PUBLIC SYNONYM clientes FOR vendas.clientes;
-- objeto remoto
CREATE SYNONYM clientes_filial FOR clientes@link_filial;
```

## Resolução de nomes

Quando uma consulta cita `clientes` sem schema, o Oracle procura, nesta ordem:

1. um objeto chamado `clientes` no schema atual (tabela, view, synonym privado...);
2. um synonym **público** chamado `clientes`.

Um objeto local esconde o synonym público de mesmo nome. Por isso, criar no próprio schema uma tabela com o nome de um synonym público usado pela aplicação muda, sem aviso, o que a aplicação lê.

## Synonym não dá permissão

O synonym só resolve o **nome**. Para consultar o objeto, o usuário continua precisando do `GRANT` no objeto de destino (`GRANT SELECT ON vendas.clientes TO app`). Sem o grant, o erro é ORA-00942, como se a tabela não existisse.

## Privilégios para criar

| Ação | Privilégio |
|---|---|
| Synonym privado no próprio schema | `CREATE SYNONYM` |
| Synonym privado em outro schema | `CREATE ANY SYNONYM` |
| Synonym público | `CREATE PUBLIC SYNONYM` (e `DROP PUBLIC SYNONYM` para remover) |

## Synonym órfão

Apagar o objeto de destino não apaga o synonym: ele continua existindo e apontando para nada. Usá-lo dá ORA-00980 (a conversão de sinônimo não é mais válida). Encontre órfãos comparando `USER_SYNONYMS` com `ALL_OBJECTS`.

## Documentação oficial

- [SQL Language Reference — CREATE SYNONYM](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/CREATE-SYNONYM.html)
