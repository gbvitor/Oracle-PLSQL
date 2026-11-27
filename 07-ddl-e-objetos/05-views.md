# Views

## O que é

Uma view é uma consulta guardada com nome. Ela não armazena dados: cada vez que é consultada, o Oracle executa a consulta de origem (normalmente fundindo-a com a consulta de quem a usa). Serve para:

- **esconder complexidade**: joins e cálculos repetidos ficam num lugar só;
- **dar uma interface estável**: a aplicação usa a view, e a estrutura das tabelas pode mudar por trás;
- **restringir acesso**: conceder `SELECT` na view, que mostra só algumas colunas ou linhas, e não na tabela.

```sql
CREATE OR REPLACE VIEW vw_vendas AS
SELECT p.id_pedido, p.data_pedido, c.nome AS cliente, ...
  FROM pedidos p
  JOIN clientes c ON ...;
```

## Opções

| Opção | Efeito |
|---|---|
| `CREATE OR REPLACE` | Substitui a definição mantendo os grants |
| `FORCE` | Cria mesmo que as tabelas não existam ainda (a view fica inválida até existirem) |
| `WITH READ ONLY` | Proíbe DML através da view |
| `WITH CHECK OPTION` | Permite DML, mas recusa linhas que ficariam **fora** do filtro da view |
| Lista de colunas: `CREATE VIEW v (a, b) AS ...` | Dá nomes às colunas sem alias na consulta |

## DML através de view

Uma view pode receber `INSERT`, `UPDATE` e `DELETE` se cada linha dela corresponder a uma linha identificável de uma tabela. **Não** é atualizável se tiver `DISTINCT`, `GROUP BY`, agregação, funções analíticas, `UNION`, `CONNECT BY` ou colunas calculadas (estas últimas só não podem ser alteradas). Em view com join, só a tabela *key-preserved* pode ser alterada (seção 06, tópico 03).

`WITH CHECK OPTION` evita a "linha que some": numa view de clientes de SP, um `UPDATE ... SET uf = 'MG'` faria a linha desaparecer da própria view. Com a opção, o comando é recusado (ORA-01402).

Para views que não são atualizáveis, triggers `INSTEAD OF` definem o que fazer em cada DML (seção 09).

## Dependências e invalidação

A view depende das tabelas que usa. Um `ALTER TABLE` que remove ou renomeia uma coluna usada pela view a deixa **inválida** (`STATUS = 'INVALID'` em `USER_OBJECTS`); o próximo uso tenta recompilar e falha se a coluna sumiu. Incluir colunas na tabela não invalida a view, mas uma view com `SELECT *` **não** passa a mostrar a coluna nova: o `*` é expandido na criação.

## Armadilhas

- **`SELECT *` em view**: a lista é fixada na criação; mudanças na tabela não aparecem até recriar a view.
- **View sobre view sobre view**: difícil de ler e de otimizar. Prefira uma camada.
- **`ORDER BY` em view**: é permitido, mas quem consulta a view deve ordenar o próprio resultado.

## Documentação oficial

- [SQL Language Reference — CREATE VIEW](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/CREATE-VIEW.html)
