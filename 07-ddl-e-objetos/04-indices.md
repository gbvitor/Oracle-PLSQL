# Índices

## Para que servem

Um índice é uma estrutura separada da tabela, ordenada pelas colunas indexadas, que guarda o `ROWID` de cada linha. Com ele, o Oracle encontra as linhas de um filtro sem ler a tabela inteira. Em troca, todo `INSERT`, `UPDATE` (das colunas indexadas) e `DELETE` precisa atualizar também os índices, e eles ocupam espaço.

## Tipos

| Tipo | Criação | Uso |
|---|---|---|
| B-tree | `CREATE INDEX ix ON t (col)` | O padrão: igualdade, faixa, ordenação, prefixo de `LIKE` |
| Único | `CREATE UNIQUE INDEX ix ON t (col)` | Garante unicidade; normalmente criado por PK/UK |
| Composto | `CREATE INDEX ix ON t (a, b)` | Filtros por `a`, ou por `a` e `b` |
| Baseado em função | `CREATE INDEX ix ON t (UPPER(nome))` | Filtros sobre a expressão exata: `WHERE UPPER(nome) = ...` |
| Bitmap | `CREATE BITMAP INDEX ix ON t (col)` | Data warehouse, colunas com poucos valores distintos, muitas leituras e quase nenhuma escrita |
| Invisível | `CREATE INDEX ix ON t (col) INVISIBLE` | Existe e é mantido, mas o otimizador ignora; para testar o efeito de criar ou de apagar um índice |
| Reverse key | `CREATE INDEX ix ON t (col) REVERSE` | Chaves sequenciais com muita inserção concorrente (RAC); não serve para faixa |

## Índice composto: a ordem das colunas

O índice `(id_cliente, data_pedido)` está ordenado por cliente e, dentro de cada cliente, por data. Ele atende:

- `WHERE id_cliente = 1` (coluna inicial);
- `WHERE id_cliente = 1 AND data_pedido >= ...`;
- `WHERE id_cliente = 1 ORDER BY data_pedido` (sem ordenar de novo).

Não atende bem `WHERE data_pedido >= ...` sozinho: as datas estão espalhadas por todos os clientes. O Oracle pode tentar um *skip scan* (percorrer o índice para cada valor da primeira coluna), que só compensa quando a primeira coluna tem poucos valores distintos.

Regra prática: primeiro as colunas comparadas por **igualdade**, depois a de **faixa** ou ordenação.

## Quando o índice não é usado

| Situação | Motivo |
|---|---|
| Função ou conversão na coluna (`TRUNC(data)`, `documento = 123`) | O índice guarda a coluna, não a expressão (seção 03, tópico 06) |
| `LIKE '%texto'` | Sem prefixo fixo não há faixa para percorrer |
| `IS NULL` em índice de uma coluna | B-tree não guarda linhas com todas as colunas indexadas nulas |
| Filtro pouco seletivo | Ler metade da tabela pelo índice é mais caro que ler a tabela toda |
| Estatísticas desatualizadas | O otimizador estima errado (seção 11) |
| Tabela pequena | Leitura completa é barata |

## Bitmap em sistema transacional

Um índice bitmap guarda, para cada valor, um mapa de bits de muitas linhas. Alterar uma linha bloqueia o pedaço do mapa que cobre várias outras: em tabela com DML concorrente, causa esperas e deadlocks. Em OLTP, não use bitmap.

## Manutenção

- `ALTER INDEX ix REBUILD [ONLINE]` reconstrói. Raramente necessário; é preciso depois de `ALTER TABLE ... MOVE` sem `UPDATE INDEXES`, quando o índice fica `UNUSABLE`.
- `ALTER INDEX ix INVISIBLE` / `VISIBLE` antes de apagar um índice suspeito de não ser usado: se algo ficar lento, basta torná-lo visível de novo.
- `ALTER INDEX ix MONITORING USAGE` e a visão `V$OBJECT_USAGE` (ou `DBA_INDEX_USAGE` a partir do 12.2) mostram se o índice foi usado.

## Documentação oficial

- [SQL Language Reference — CREATE INDEX](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/CREATE-INDEX.html)
- [Database Concepts — Indexes and Index-Organized Tables](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/indexes-and-index-organized-tables.html)
