# Índices: USER_INDEXES, USER_IND_COLUMNS, USER_IND_EXPRESSIONS

## As visões

| Visão | Uma linha por | Colunas mais usadas |
|---|---|---|
| `USER_INDEXES` | Índice | `INDEX_NAME`, `TABLE_NAME`, `INDEX_TYPE`, `UNIQUENESS`, `STATUS`, `VISIBILITY`, `BLEVEL`, `LEAF_BLOCKS`, `DISTINCT_KEYS`, `NUM_ROWS`, `CLUSTERING_FACTOR`, `LAST_ANALYZED` |
| `USER_IND_COLUMNS` | Coluna de índice | `INDEX_NAME`, `TABLE_NAME`, `COLUMN_NAME`, `COLUMN_POSITION`, `DESCEND` |
| `USER_IND_EXPRESSIONS` | Expressão de índice baseado em função | `COLUMN_EXPRESSION` (LONG), `COLUMN_POSITION` |
| `USER_SEGMENTS` | Segmento (tabela, índice, LOB...) | `SEGMENT_NAME`, `SEGMENT_TYPE`, `BYTES` |

Em índice baseado em função, `USER_IND_COLUMNS.COLUMN_NAME` traz um nome gerado (`SYS_NC00011$`); a expressão real está em `USER_IND_EXPRESSIONS`.

## O que as estatísticas do índice dizem

| Coluna | Leitura |
|---|---|
| `BLEVEL` | Altura da árvore menos 1. Quase sempre 0 a 3, mesmo em tabelas enormes |
| `NUM_ROWS` | Entradas no índice. **Linhas com todas as colunas indexadas NULL não entram** em índice B-tree: por isso `WHERE coluna IS NULL` não usa o índice de uma coluna só |
| `DISTINCT_KEYS` | Valores distintos: perto de `NUM_ROWS` = seletivo; muito menor = muitas repetições |
| `CLUSTERING_FACTOR` | Perto do número de blocos da tabela = dados ordenados como o índice (bom para varredura por faixa); perto do número de linhas = espalhados |

Detalhes de quando o otimizador usa ou ignora um índice: seção 11, tópico 06.

## Auditorias comuns

- **FK sem índice**: tópico 03.
- **Índice redundante**: um índice em `(a)` é coberto por outro em `(a, b)`, que serve para as mesmas buscas por `a`. O redundante só custa (espaço, DML mais lento). Exceção: quando o `(a)` é único e sustenta uma constraint.
- **Índice inválido**: `STATUS = 'UNUSABLE'` depois de `ALTER TABLE ... MOVE` ou operação de partição; consultas que dependem dele passam a falhar ou a ignorá-lo, e o DML pode dar ORA-01502.
- **Índice nunca usado**: `DBA_INDEX_USAGE` `[12.2+]` registra uso automaticamente; em versões antigas, `ALTER INDEX ... MONITORING USAGE` e `V$OBJECT_USAGE`. Antes de excluir, lembre que um índice pode ser usado só no fechamento do mês.
- **Índice invisível**: `VISIBILITY = 'INVISIBLE'`, mantido pelo DML mas ignorado pelo otimizador (seção 07, tópico 04).

## Documentação oficial

- [Database Reference — ALL_INDEXES](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/ALL_INDEXES.html)
- [Database Reference — ALL_IND_COLUMNS](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/ALL_IND_COLUMNS.html)
- [Database Reference — DBA_INDEX_USAGE](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/DBA_INDEX_USAGE.html)
