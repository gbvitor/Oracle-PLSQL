# LEFT, RIGHT e FULL OUTER JOIN

## O que fazem

| Join | Mantém | Colunas do lado sem par |
|---|---|---|
| `LEFT [OUTER] JOIN` | Todas as linhas da tabela da **esquerda** | NULL nas colunas da direita |
| `RIGHT [OUTER] JOIN` | Todas as linhas da tabela da **direita** | NULL nas colunas da esquerda |
| `FULL [OUTER] JOIN` | Todas as linhas dos **dois** lados | NULL do lado que não tem par |

`RIGHT JOIN` é um `LEFT JOIN` com as tabelas trocadas. Na prática, use sempre `LEFT` e escreva primeiro a tabela que não pode perder linhas: a consulta fica mais fácil de ler.

## ON ou WHERE

No inner join tanto faz. No outer join, **o lugar da condição muda o resultado**:

| Condição sobre a tabela opcional | Efeito |
|---|---|
| No `ON` | Restringe **quais linhas servem de par**. Quem não tem par continua no resultado, com NULL |
| No `WHERE` | Filtra **depois** do join. As linhas sem par têm NULL na coluna, a condição dá UNKNOWN, e elas somem: o outer join vira inner |

```sql
-- Todos os clientes, com os pedidos em aberto se houver: 12 linhas ou mais
FROM clientes c LEFT JOIN pedidos p ON p.id_cliente = c.id_cliente AND p.status = 'ABERTO'

-- Só os clientes com pedido em aberto: o LEFT JOIN não serve para nada aqui
FROM clientes c LEFT JOIN pedidos p ON p.id_cliente = c.id_cliente
WHERE p.status = 'ABERTO'
```

A exceção é o padrão anti-join: `WHERE p.id_pedido IS NULL` (sobre a chave da tabela opcional) seleciona justamente quem **não** tem par.

## Contagem depois do outer join

`COUNT(*)` conta a linha do cliente sem pedido como 1. Para contar pedidos, `COUNT(p.id_pedido)`, que ignora o NULL.

## Encadeamento

Depois de um `LEFT JOIN`, um `JOIN` (inner) com uma tabela ligada ao lado opcional elimina as linhas sem par:

```sql
FROM clientes c
LEFT JOIN pedidos p      ON p.id_cliente = c.id_cliente
     JOIN itens_pedido i ON i.id_pedido  = p.id_pedido   -- clientes sem pedido somem aqui
```

Toda a cadeia a partir do lado opcional precisa ser `LEFT JOIN`.

## FULL OUTER JOIN

Útil para **comparar** dois conjuntos: o que está só em A, só em B e nos dois. Exemplo: departamentos sem funcionário e funcionários sem departamento numa consulta só, ou conciliação entre duas tabelas (seção 15).

## Documentação oficial

- [SQL Language Reference — Joins (Outer Joins)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Joins.html)
