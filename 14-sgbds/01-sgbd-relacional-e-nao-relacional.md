# O que é um SGBD; relacional versus não relacional

## SGBD

Um **Sistema Gerenciador de Banco de Dados** é o software entre os dados e quem os usa. Além de guardar e devolver dados, ele garante o que um arquivo comum não garante:

| Responsabilidade | O que significa na prática |
|---|---|
| Linguagem de consulta | Pedir *o quê* (SQL), não *como* ler os arquivos |
| Integridade | Tipos, chaves, constraints: dado inválido é recusado |
| Concorrência | Muitos usuários lendo e gravando ao mesmo tempo sem se atrapalhar (tópico 02) |
| Transações | Um conjunto de mudanças acontece por inteiro ou não acontece |
| Recuperação | Depois de queda de energia ou falha, o banco volta consistente |
| Segurança | Usuários, privilégios, auditoria |
| Otimização | O mesmo SQL executado pelo caminho mais barato (seção 11) |

## Modelo relacional

Os dados ficam em **tabelas** (relações) de linhas e colunas, ligadas por **chaves**. As consultas combinam tabelas por junção. É o modelo de Oracle, PostgreSQL, SQL Server, MySQL/MariaDB, SQLite, Db2. Pontos fortes: integridade declarada, consultas arbitrárias sobre os mesmos dados, transações, maturidade de décadas.

## Modelos não relacionais (NoSQL)

| Tipo | Como guarda | Exemplos | Bom para |
|---|---|---|---|
| Documento | Documentos JSON com estrutura variável | MongoDB, Couchbase | Catálogos e cadastros com atributos muito variáveis; dado lido inteiro por chave |
| Chave-valor | Valor opaco por chave | Redis, DynamoDB | Cache, sessão, contadores, filas simples, com latência mínima |
| Colunar largo (wide-column) | Linhas com famílias de colunas, distribuídas por chave | Cassandra, HBase | Escrita massiva distribuída (telemetria, eventos) com consultas previsíveis |
| Grafo | Nós e arestas | Neo4j | Relações de muitos níveis: redes, recomendação, fraude |
| Séries temporais | Pontos com carimbo de tempo | InfluxDB, TimescaleDB | Métricas, sensores |
| Busca | Índice invertido de texto | Elasticsearch, OpenSearch | Busca textual, logs |

Em troca de escala horizontal simples ou de flexibilidade de estrutura, muitos abrem mão de parte das garantias: junções, transações entre vários registros, consistência imediata (em sistemas distribuídos, *consistência eventual*). O desenho passa a partir das consultas que a aplicação fará, e consulta nova pode exigir dado duplicado em outra estrutura.

## A fronteira está menos nítida

- Bancos relacionais guardam e consultam JSON (Oracle `JSON`, PostgreSQL `jsonb`, MySQL `JSON`), texto, dados geográficos, grafos (Oracle SQL/PGQ `[23ai+]`).
- `[23ai+]` Oracle *JSON Relational Duality*: os mesmos dados vistos como tabelas e como documentos JSON atualizáveis.
- Bancos NoSQL ganharam transações e linguagens parecidas com SQL.

Critério prático: dados de negócio com regras, relações e necessidade de consultas não previstas (financeiro, estoque, faturamento, cadastros) ficam melhor num relacional. Um NoSQL entra para um problema específico (cache, busca, telemetria), ao lado do relacional, não no lugar dele.

## Documentação

- [Oracle Database Concepts — Introduction to Oracle Database](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/introduction-to-oracle-database.html)
- [PostgreSQL — Documentation](https://www.postgresql.org/docs/current/)
