# Subquery escalar

## O que é

Uma subquery que devolve **no máximo uma linha com uma coluna** e por isso pode ser usada em qualquer lugar onde caberia um valor: lista do `SELECT`, `WHERE`, `ORDER BY`, `CASE`, `VALUES` de um `INSERT`, `SET` de um `UPDATE`.

```sql
SELECT c.nome,
       (SELECT MAX(p.data_pedido)
          FROM pedidos p
         WHERE p.id_cliente = c.id_cliente) AS ultimo_pedido
  FROM clientes c;
```

Quando ela usa colunas da consulta de fora (`c.id_cliente`), é **correlacionada**: é avaliada para cada linha de fora.

## Regras

| A subquery devolve | Resultado |
|---|---|
| Uma linha | O valor |
| Nenhuma linha | **NULL** (sem erro) |
| Mais de uma linha | **ORA-01427** (subquery de uma única linha retorna mais de uma linha) |
| Mais de uma coluna | ORA-00913 (valores demais) |

O caso "nenhuma linha vira NULL" é útil (cliente sem pedido aparece com data nula, sem precisar de outer join) e perigoso (um filtro errado na subquery não dá erro, só NULL).

## Desempenho

- O Oracle guarda em memória os resultados recentes da subquery por valor de entrada (*scalar subquery caching*). Se muitas linhas de fora têm o mesmo `id_cliente`, a subquery roda uma vez por cliente distinto, não uma vez por linha.
- Mesmo assim, várias subqueries escalares sobre a mesma tabela (último pedido, quantidade de pedidos, valor total) leem a tabela várias vezes. Nesse caso, um join com uma inline view agregada lê uma vez só.
- A partir do 12c, o otimizador às vezes transforma a subquery escalar em join sozinho (*scalar subquery unnesting*).

## Quando usar

- Um ou dois valores de apoio por linha, com leitura clara.
- Quando o outer join mudaria a granularidade do resultado.
- Em `UPDATE ... SET coluna = (SELECT ...)`, que é a forma padrão de atualizar a partir de outra tabela (seção 06).

## Armadilhas

- **ORA-01427 só aparece com certos dados.** A subquery funciona no teste e quebra em produção no dia em que surge a segunda linha. Garanta unicidade pela chave ou pela agregação (`MAX`, `MIN`, `FETCH FIRST 1 ROW ONLY`).
- **NULL silencioso.** No `UPDATE ... SET col = (SELECT ...)` sem `WHERE EXISTS`, as linhas sem correspondência recebem NULL.

## Documentação oficial

- [SQL Language Reference — Scalar Subquery Expressions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Scalar-Subquery-Expressions.html)
