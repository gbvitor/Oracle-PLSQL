# Objetos e código: USER_OBJECTS, USER_SOURCE, USER_PROCEDURES, USER_ARGUMENTS

## As visões

| Visão | Uma linha por | Para |
|---|---|---|
| `USER_OBJECTS` | Objeto (tabela, índice, view, procedure, package, trigger, tipo, sequence...) | Inventário, situação (`STATUS`), datas (`CREATED`, `LAST_DDL_TIME`) |
| `USER_SOURCE` | **Linha** de código de procedure, function, package, trigger ou tipo | Ler e pesquisar o código |
| `USER_PROCEDURES` | Rotina, inclusive cada procedure/function **dentro** de uma package | API de cada package, `AUTHID`, `DETERMINISTIC`, `PIPELINED` |
| `USER_ARGUMENTS` | Parâmetro de rotina | Assinatura: nome, posição, tipo, modo (`IN`/`OUT`), se tem `DEFAULT` |
| `USER_ERRORS` | Erro de compilação | Linha, coluna e mensagem |
| `USER_VIEWS` | View | Texto da consulta (`TEXT`, LONG) |

## Datas em USER_OBJECTS

| Coluna | Muda quando |
|---|---|
| `CREATED` | O objeto é criado (CREATE OR REPLACE **não** muda) |
| `LAST_DDL_TIME` | Qualquer DDL: recompilação, GRANT, ALTER, CREATE OR REPLACE |
| `TIMESTAMP` | A especificação muda (é o que a dependência compara) |

"O que mudou no banco desde ontem?" é uma consulta por `LAST_DDL_TIME`. Note que um GRANT também altera a data; para saber o que mudou de fato, compare o código com o versionamento.

## Pesquisar no código

`USER_SOURCE` guarda o código linha a linha (`NAME`, `TYPE`, `LINE`, `TEXT`). Responde a "em que procedures esta tabela aparece?", "quem chama esta function?", "onde está este número mágico?":

```sql
SELECT name, type, line, TRIM(text)
  FROM user_source
 WHERE UPPER(text) LIKE '%ITENS_PEDIDO%'
 ORDER BY name, type, line;
```

Complementa `USER_DEPENDENCIES` (tópico 06), que não enxerga SQL dinâmico nem comentários. Limites: um nome quebrado em duas linhas não é encontrado; código **wrapped** (ofuscado com `wrap`) não é legível.

## Código completo: DBMS_METADATA

`USER_SOURCE` não traz o `CREATE OR REPLACE` nem o `/`. Para reconstruir o objeto inteiro, pronto para rodar ou versionar, `DBMS_METADATA.GET_DDL('PACKAGE', 'NOME')` (seção 07, tópico 12). Para package, `'PACKAGE'` traz especificação e corpo; `'PACKAGE_SPEC'` e `'PACKAGE_BODY'` separados.

## A API de uma package sem abrir o código

`USER_PROCEDURES` lista as rotinas públicas de cada package (`OBJECT_NAME` = package, `PROCEDURE_NAME` = rotina), e `USER_ARGUMENTS` os parâmetros. Em function, o retorno aparece como argumento de **posição 0** e sem nome. Rotina sobrecarregada tem `OVERLOAD` 1, 2, ...

## Documentação oficial

- [Database Reference — ALL_OBJECTS](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/ALL_OBJECTS.html)
- [Database Reference — ALL_SOURCE](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/ALL_SOURCE.html)
- [Database Reference — ALL_PROCEDURES](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/ALL_PROCEDURES.html)
- [Database Reference — ALL_ARGUMENTS](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/ALL_ARGUMENTS.html)
