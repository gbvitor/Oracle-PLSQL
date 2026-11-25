# EXISTS e NOT EXISTS

## O que faz

`EXISTS (subquery)` é verdadeiro se a subquery devolve **pelo menos uma linha**, e falso se não devolve nenhuma. Nunca é UNKNOWN: não há NULL envolvido no resultado.

```sql
-- Clientes que têm pelo menos um pedido
SELECT c.nome
  FROM clientes c
 WHERE EXISTS (SELECT 1 FROM pedidos p WHERE p.id_cliente = c.id_cliente);

-- Clientes sem nenhum pedido
SELECT c.nome
  FROM clientes c
 WHERE NOT EXISTS (SELECT 1 FROM pedidos p WHERE p.id_cliente = c.id_cliente);
```

A subquery quase sempre é **correlacionada** (usa coluna da consulta de fora). Sem correlação, ela dá o mesmo resultado para todas as linhas: ou todas passam, ou nenhuma.

## Detalhes

- **O que vai no SELECT da subquery não importa.** `SELECT 1`, `SELECT *`, `SELECT NULL` dão o mesmo resultado; `SELECT 1` é a convenção que deixa claro que só a existência conta.
- **Não multiplica linhas.** Um cliente com 4 pedidos aparece uma vez, ao contrário de um join.
- **Para na primeira linha encontrada.** O Oracle não precisa ler todos os pedidos do cliente.
- O otimizador transforma `EXISTS` em **semi-join** e `NOT EXISTS` em **anti-join**, o mesmo que faria com `IN` / `NOT IN` sem nulos.

## Comparação

| Pergunta | Forma recomendada | Por quê |
|---|---|---|
| "Tem pelo menos um" | `EXISTS` ou `IN (subquery)` | Equivalentes; escolha pela leitura |
| "Não tem nenhum" | `NOT EXISTS` | `NOT IN` falha com NULL (tópico 09) |
| "Tem, e quero dados do outro lado" | `JOIN` | `EXISTS` só filtra; não traz colunas da subquery |
| "Não tem", com outer join | `LEFT JOIN ... WHERE b.chave IS NULL` | Equivalente ao `NOT EXISTS`; menos explícito |

## Condições adicionais

A subquery aceita qualquer filtro além da correlação. "Clientes que têm pedido em 2026" e "produtos que nunca foram vendidos com desconto" são `EXISTS` / `NOT EXISTS` com condições extras dentro.

## Documentação oficial

- [SQL Language Reference — EXISTS Condition](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/EXISTS-Condition.html)
