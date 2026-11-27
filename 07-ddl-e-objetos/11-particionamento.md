# Particionamento (visão geral)

## O que é

Uma tabela particionada é uma tabela lógica dividida em **partições** físicas, cada uma com parte das linhas, definida por uma **chave de particionamento**. Para quem consulta, continua sendo uma tabela só; por baixo, o Oracle pode ler só as partições necessárias e administrar cada uma separadamente.

**Licença**: particionamento é uma **opção paga** da Enterprise Edition. Antes de usar num banco da empresa, confirme se ela está licenciada. Para saber se está habilitada na instalação: `SELECT value FROM v$option WHERE parameter = 'Partitioning'`.

## Tipos

| Tipo | Divide por | Exemplo |
|---|---|---|
| Range | Faixas de valor | Um mês por partição |
| Interval `[11g+]` | Range com criação **automática** de partições novas | `INTERVAL (NUMTOYMINTERVAL(1, 'MONTH'))` |
| List | Lista de valores | Uma partição por UF ou por empresa |
| Hash | Função de hash | Espalhar linhas igualmente quando não há critério natural |
| Composto | Dois níveis (range-list, range-hash, list-list...) | Mês e, dentro dele, UF |
| Reference | A chave da tabela pai, via FK | Itens particionados junto com os pedidos |

## Benefícios

- **Partition pruning**: com filtro na chave (`WHERE data_pedido >= DATE '2026-01-01'`), o Oracle lê só as partições que podem ter as linhas. No plano, aparece como `PARTITION RANGE SINGLE` / `ITERATOR`, com as colunas `Pstart` e `Pstop`.
- **Manutenção por partição**: `ALTER TABLE ... DROP PARTITION` (apagar um mês inteiro na hora, em vez de um `DELETE` enorme), `TRUNCATE PARTITION`, `EXCHANGE PARTITION` (trocar uma partição por uma tabela já carregada, instantaneamente), compressão ou tablespace diferentes para dados antigos.
- **Paralelismo** por partição.

## Índices

| Tipo | Estrutura | Comportamento |
|---|---|---|
| Local | Um índice por partição, particionado como a tabela | Manutenção de partição afeta só a parte correspondente |
| Global | Um índice para a tabela inteira (ou particionado de outro jeito) | `DROP`/`TRUNCATE PARTITION` o deixa `UNUSABLE`, salvo com `UPDATE INDEXES` |

## Quando considerar

Tabelas grandes (a documentação sugere considerar a partir de 2 GB) com um critério natural de acesso e de expurgo, quase sempre data. Particionar tabela pequena, ou por uma coluna que as consultas não filtram, só acrescenta complexidade.

## Documentação oficial

- [VLDB and Partitioning Guide 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/vldbg/index.html)
