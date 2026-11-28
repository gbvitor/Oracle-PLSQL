# Constraints e chaves: USER_CONSTRAINTS, USER_CONS_COLUMNS e o mapa de FKs

## As visões

| Visão | Uma linha por | Colunas mais usadas |
|---|---|---|
| `USER_CONSTRAINTS` | Constraint | `CONSTRAINT_NAME`, `CONSTRAINT_TYPE`, `TABLE_NAME`, `R_CONSTRAINT_NAME`, `DELETE_RULE`, `STATUS`, `VALIDATED`, `GENERATED`, `SEARCH_CONDITION` (LONG), `INDEX_NAME` |
| `USER_CONS_COLUMNS` | Coluna de constraint | `CONSTRAINT_NAME`, `TABLE_NAME`, `COLUMN_NAME`, `POSITION` |

## CONSTRAINT_TYPE

| Código | Tipo |
|---|---|
| `P` | Chave primária |
| `U` | Única |
| `R` | Chave estrangeira (*referential*) |
| `C` | CHECK, **incluindo `NOT NULL`** |
| `V`, `O` | WITH CHECK OPTION e WITH READ ONLY de view |

Cada `NOT NULL` vira uma constraint `C` com nome gerado (`SYS_C0012345`, `GENERATED = 'GENERATED NAME'`). No schema de exemplo, são 28 das 37 constraints `C`. Para listar só as regras de negócio, filtre `GENERATED = 'USER NAME'`, ou dê nome a toda constraint (seção 07, tópico 02).

## Como a FK aponta para o pai

A FK não guarda o nome da tabela pai: guarda o nome da **constraint** do pai (`R_CONSTRAINT_NAME`), que é a PK ou uma UK. O mapa de FKs é um JOIN de `USER_CONSTRAINTS` com ela mesma:

```
filho (constraint R) --R_CONSTRAINT_NAME--> pai (constraint P ou U)
```

e, para as colunas, `USER_CONS_COLUMNS` dos dois lados ligado por `POSITION`: a coluna 1 da FK corresponde à coluna 1 da PK. Ligar só por nome de constraint e não por posição duplica linhas em FK composta.

## Situação da constraint

| `STATUS` | `VALIDATED` | Significa |
|---|---|---|
| ENABLED | VALIDATED | Vale para dados novos e foi conferida nos existentes |
| ENABLED | NOT VALIDATED | Vale para dados novos; os antigos podem violar (`ENABLE NOVALIDATE`) |
| DISABLED | NOT VALIDATED | Não vale. Comum depois de carga em massa que alguém esqueceu de reabilitar |

`RELY` informa ao otimizador que a regra é confiável mesmo sem validação (data warehouse).

## FK sem índice

O Oracle cria índice automaticamente para PK e UK, **não para FK**. FK sem índice na coluna filha causa lock da tabela filha inteira em `DELETE` ou `UPDATE` da chave do pai, e joins mais caros (seção 06, tópico 08). A consulta do script lista as FKs cujas colunas não aparecem nas mesmas posições iniciais de algum índice; é uma aproximação suficiente para uma auditoria.

## Documentação oficial

- [Database Reference — ALL_CONSTRAINTS](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/ALL_CONSTRAINTS.html)
- [Database Reference — ALL_CONS_COLUMNS](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/ALL_CONS_COLUMNS.html)
