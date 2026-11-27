# 07 — DDL e objetos

Criação e manutenção de objetos do banco e como extrair a definição de um objeto existente.

## Tópicos

### Tabelas e regras

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 01 | Tabelas: CREATE, CTAS, ALTER, DROP, lixeira, FLASHBACK TABLE, IF EXISTS | [md](01-tabelas.md) | [sql](01-tabelas.sql) |
| 02 | Constraints: PK, UK, FK (CASCADE, SET NULL), CHECK, NOT NULL | [md](02-constraints.md) | [sql](02-constraints.sql) |
| 03 | Estados de constraint: DISABLE, NOVALIDATE, DEFERRABLE | [md](03-estados-de-constraint.md) | [sql](03-estados-de-constraint.sql) |
| 09 | Colunas virtuais, DEFAULT e colunas invisíveis | [md](09-colunas-virtuais-e-default.md) | [sql](09-colunas-virtuais-e-default.sql) |

### Acesso e desempenho

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 04 | Índices: B-tree, composto, função, bitmap, invisível; quando não são usados | [md](04-indices.md) | [sql](04-indices.sql) |
| 11 | Particionamento: interval, list, pruning, manutenção (opção paga) | [md](11-particionamento.md) | [sql](11-particionamento.sql) |

### Outros objetos

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 05 | Views: CHECK OPTION, READ ONLY, DML, invalidação | [md](05-views.md) | [sql](05-views.sql) |
| 06 | Materialized views: refresh completo, rápido, ON COMMIT, MV log | [md](06-materialized-views.md) | [sql](06-materialized-views.sql) |
| 07 | Sequences e colunas IDENTITY | [md](07-sequences-e-identity.md) | [sql](07-sequences-e-identity.sql) |
| 08 | Synonyms privados e públicos | [md](08-synonyms.md) | [sql](08-synonyms.sql) |
| 10 | Tabelas temporárias: GTT e private temporary table `[18c+]` | [md](10-tabelas-temporarias.md) | [sql](10-tabelas-temporarias.sql) |

### Documentação e extração

| # | Tópico | Explicação | Script |
|---|---|---|---|
| 12 | COMMENT ON e extração de DDL com DBMS_METADATA.GET_DDL | [md](12-comentarios-e-dbms-metadata.md) | [sql](12-comentarios-e-dbms-metadata.sql) |

## Observações

- Todo DDL faz commit implícito ([seção 01, tópico 10](../01-fundamentos/10-categorias-de-comando.md)). Os scripts criam objetos com prefixo `tmp_` e os removem no fim.
- O tópico 04 cria uma tabela de 100 mil linhas para que o otimizador tenha motivo para usar índices; o schema de exemplo é pequeno demais para isso.
- O tópico 11 depende da opção Partitioning; o script confere antes.
