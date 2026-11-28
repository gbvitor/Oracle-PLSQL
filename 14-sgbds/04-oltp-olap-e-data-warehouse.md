# OLTP versus OLAP; data warehouse

## Dois tipos de carga

| | OLTP (transacional) | OLAP (analítico) |
|---|---|---|
| Para | Operar o negócio: vender, faturar, baixar estoque | Analisar o negócio: vendas por região no ano, margem por produto |
| Consultas | Muitas, curtas, poucas linhas, por chave | Poucas, longas, milhões de linhas, agregações |
| Escrita | Constante, linha a linha | Em cargas periódicas (noturna, de hora em hora) |
| Modelo | Normalizado (tópico 03) | Dimensional, desnormalizado |
| Histórico | O estado atual | Anos de história, inclusive de como as coisas eram |
| Exemplo | O ERP | O data warehouse e os painéis de BI |

Rodar relatório pesado direto no banco transacional disputa CPU, memória e disco com a operação, e (no SQL Server sem snapshot, tópico 02) ainda trava linhas. A separação mais simples é uma réplica de leitura para relatórios; a completa, um data warehouse.

## Data warehouse e modelo dimensional

O modelo mais usado é o **esquema estrela** (*star schema*):

- **Fato**: os eventos medidos, com as métricas. `fato_vendas(id_data, id_produto, id_cliente, id_vendedor, quantidade, valor_liquido, custo)`. Uma linha por item vendido. Tabela enorme, estreita.
- **Dimensões**: o contexto, com os atributos para filtrar e agrupar. `dim_produto(id_produto, nome, categoria, subcategoria, marca)`, `dim_cliente(..., cidade, uf, segmento)`, `dim_data(id_data, data, dia_semana, mes, trimestre, ano, feriado)`. Tabelas menores, largas e desnormalizadas: a categoria e a subcategoria ficam na própria dimensão de produto.

Consultas típicas: junção do fato com algumas dimensões, filtros nas dimensões, `SUM` nas métricas. O **floco de neve** (*snowflake*) normaliza as dimensões (categoria em tabela própria); economiza espaço e complica as consultas.

### Dimensões que mudam (SCD)

O cliente mudou de cidade. As vendas antigas devem aparecer na cidade antiga ou na nova?

| Tipo | Comportamento |
|---|---|
| SCD 1 | Sobrescreve: todo o histórico passa para a cidade nova |
| SCD 2 | Nova linha na dimensão, com vigência (`data_inicio`, `data_fim`, `atual = 'S'`): vendas antigas continuam na cidade antiga |
| SCD 3 | Coluna `cidade_anterior`: guarda só a última mudança |

SCD 2 é o padrão quando a pergunta "como era na época" importa (região do vendedor, segmento do cliente).

## Carga: ETL e ELT

- **ETL**: extrair da origem, transformar numa ferramenta à parte, carregar pronto.
- **ELT**: extrair e carregar bruto no destino, transformar lá com SQL. Comum com bancos analíticos e nuvem.

Em Oracle, o ELT feito com `INSERT /*+ APPEND */ ... SELECT`, `MERGE`, particionamento por data (troca de partição para carga), materialized views e PL/SQL em lote (seção 09, tópico 08) cobre data warehouses grandes.

## Armazenamento analítico

Bancos analíticos guardam por **coluna** em vez de por linha: somar uma coluna lê só aquela coluna, comprimida. Exemplos: Snowflake, BigQuery, Redshift, ClickHouse, DuckDB (local, embutido: o mesmo usado para conferir os valores deste repositório). No Oracle, o equivalente é a opção **Database In-Memory** (cópia colunar em memória; opção paga da Enterprise Edition, com uma versão básica gratuita limitada a 16 GB a partir do 19.8) e a compressão colunar do Exadata.

**Lakehouse**: arquivos colunares abertos (Parquet, Iceberg, Delta) em armazenamento de objetos, consultados por vários motores. É para onde muitas plataformas analíticas novas vão; o modelo dimensional continua valendo por cima deles.

## Documentação

- [Oracle Database Data Warehousing Guide](https://docs.oracle.com/en/database/oracle/oracle-database/19/dwhsg/index.html)
- Ralph Kimball e Margy Ross, *The Data Warehouse Toolkit*: a referência do modelo dimensional
