# CROSS JOIN, self join, NATURAL JOIN e USING

## CROSS JOIN

Combina **cada linha** de uma tabela com **cada linha** da outra (produto cartesiano): 5 vendedores × 12 meses = 60 linhas.

```sql
FROM vendedores v CROSS JOIN meses m
```

Uso legítimo: montar uma **grade completa** (todo vendedor em todo mês, todo produto em toda filial) e depois fazer `LEFT JOIN` com os dados reais, para que as combinações sem movimento apareçam com zero. Uso acidental: esquecer a condição de join na sintaxe com vírgula.

## Self join

A mesma tabela aparece duas vezes, com aliases diferentes. Casos típicos:

- **Auto-relacionamento**: funcionário e seu gerente (`funcionarios f JOIN funcionarios g ON g.id_funcionario = f.id_gerente`).
- **Comparar linhas entre si**: clientes da mesma cidade, pedidos do mesmo cliente em datas próximas.

Para comparar pares sem repetir (A com B e B com A) nem comparar a linha com ela mesma, use `a.id < b.id`.

## NATURAL JOIN

Faz o join automaticamente por **todas as colunas com o mesmo nome** nas duas tabelas.

```sql
SELECT * FROM produtos NATURAL JOIN itens_pedido;
```

`produtos` e `itens_pedido` têm em comum `id_produto` **e** `preco_unitario`. O natural join liga pelas duas, e o resultado traz só os itens vendidos exatamente pelo preço de tabela. Ninguém pediu isso, e nenhum erro avisa. Se alguém acrescentar uma coluna `ativo` ou `data_alteracao` nas duas tabelas, o resultado muda de novo.

**Não use `NATURAL JOIN` em código que fica.**

## USING

Join por igualdade em colunas de **mesmo nome**, escolhidas explicitamente:

```sql
SELECT id_pedido, c.nome
  FROM pedidos p
  JOIN clientes c USING (id_cliente);
```

- A coluna do `USING` aparece uma vez só no resultado e **não pode ser qualificada** com alias (`p.id_cliente` dá ORA-25154).
- É seguro, ao contrário do `NATURAL`, porque a lista de colunas é explícita.
- Fica limitado a colunas com nomes iguais; com nomes diferentes (`id_vendedor` × `id_funcionario`), use `ON`.

## Documentação oficial

- [SQL Language Reference — Joins](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Joins.html)
