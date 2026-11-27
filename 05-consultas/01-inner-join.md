# INNER JOIN

## O que faz

Combina linhas de duas tabelas quando a condição do `ON` é verdadeira. **Só ficam as linhas que têm par** nos dois lados.

```sql
SELECT p.id_pedido, c.nome
  FROM pedidos  p
  JOIN clientes c ON c.id_cliente = p.id_cliente;
```

`JOIN` e `INNER JOIN` são a mesma coisa.

## Tipos de condição

| Tipo | Exemplo | Uso |
|---|---|---|
| Igualdade (equi-join) | `ON c.id_cliente = p.id_cliente` | FK com PK: o caso comum |
| Várias colunas | `ON a.id_pedido = b.id_pedido AND a.nr_item = b.nr_item` | Chave composta |
| Desigualdade (non-equi) | `ON i.pct_desconto BETWEEN f.minimo AND f.maximo` | Faixas, tabelas de preço por vigência, comissão por meta |
| Condição extra | `ON ... AND p.status <> 'CANCELADO'` | Em inner join, equivale a pôr no `WHERE` |

## O que o inner join tira do resultado

- Linhas da tabela A **sem par** em B.
- Linhas com **FK nula**: `pedidos.id_vendedor` é nulo para vendas pelo site, e `NULL = qualquer coisa` nunca é verdadeiro. Um join de pedidos com funcionários perde esses pedidos sem aviso.

Quando a pergunta é "todos os pedidos, com o vendedor se houver", o join é externo (tópico 02).

## Granularidade

O resultado tem uma linha **por combinação** que satisfaz a condição. Juntar pedidos com itens dá uma linha por item; somar uma coluna do pedido depois disso soma o mesmo valor várias vezes. Antes de juntar, pergunte: "cada linha do resultado representa o quê?". Se a resposta for diferente do que a consulta precisa, agregue antes, numa inline view (seção 02, tópico 02).

## Ordem das tabelas

Para inner join, a ordem em que as tabelas aparecem não muda o resultado; o otimizador escolhe a ordem de execução. Escreva na ordem que deixa a leitura mais natural, normalmente da tabela principal da pergunta para as de apoio.

## Documentação oficial

- [SQL Language Reference — Joins](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Joins.html)
