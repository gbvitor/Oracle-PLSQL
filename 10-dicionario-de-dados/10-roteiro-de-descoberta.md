# Roteiro de descoberta de um schema desconhecido

Situação: você recebeu acesso a um banco que não conhece (um sistema legado, um ERP, a base de um fornecedor) e precisa entender o que há ali antes de escrever a primeira consulta. O dicionário responde quase tudo sem abrir nenhum documento. O script deste tópico roda o roteiro inteiro sobre um schema escolhido numa variável de ligação (`:dono`); por padrão, o próprio usuário.

## A ordem

| # | Pergunta | Onde |
|---|---|---|
| 1 | O que existe, e quanto? | `ALL_OBJECTS` por tipo |
| 2 | Quais são as tabelas grandes? | `ALL_TABLES.NUM_ROWS` (estatística) e `DBA_SEGMENTS` (espaço) |
| 3 | Toda tabela tem chave primária? | `ALL_CONSTRAINTS` tipo `P` |
| 4 | Como as tabelas se ligam? | Mapa de FKs (tópico 03) |
| 5 | Em que ordem carregar ou excluir? | Níveis do grafo de FKs (WITH recursivo) |
| 6 | Há ligações não declaradas? | Colunas `ID_%`/`CD_%`/`COD_%` fora de PK e FK |
| 7 | As FKs têm índice? | Tópico 03 |
| 8 | Que código e triggers mexem nos dados? | `ALL_OBJECTS`, `ALL_TRIGGERS`, `ALL_SOURCE` |
| 9 | O que está documentado? | `ALL_TAB_COMMENTS`, `ALL_COL_COMMENTS` |
| 10 | Ficha de cada tabela | Uma linha por tabela juntando tudo |

## O que o dicionário não diz

- **Semântica.** Que `STATUS = 'F'` significa "faturado", que uma coluna chamada `VALOR` é bruta e não líquida, que um campo foi reaproveitado para outra coisa. Isso vem de olhar os dados (`SELECT coluna, COUNT(*) ... GROUP BY`), do código que grava e de quem usa o sistema.
- **FKs não declaradas.** Muitos sistemas comerciais não declaram FKs por desempenho ou por herança. O passo 6 dá candidatas por nome; a confirmação é por dado (`LEFT JOIN` procurando órfãos).
- **Uso real.** Tabelas com `NUM_ROWS = 0` ou com `LAST_ANALYZED` muito antigo podem estar abandonadas; tabelas sem índice nenhum e com milhões de linhas costumam ser log ou staging.

Tratar o resultado do roteiro como **hipótese** sobre o sistema, a confirmar com dados e com quem conhece a operação, evita a maioria dos erros de análise em base desconhecida.

## Documentação oficial

- [Database Reference — Static Data Dictionary Views](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/about-static-data-dictionary-views.html)
- [SQL Language Reference — Recursive Subquery Factoring](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SELECT.html)
