# WITH (subquery factoring / CTE)

## O que é

`WITH` dá nome a uma subquery no início do comando. O nome pode ser usado no resto da consulta como se fosse uma tabela. A Oracle chama de *subquery factoring*; no padrão SQL é *common table expression* (CTE).

```sql
WITH vendas_vendedor AS (
    SELECT id_vendedor, SUM(...) AS total
      FROM ...
     GROUP BY id_vendedor
)
SELECT *
  FROM vendas_vendedor
 WHERE total > (SELECT AVG(total) FROM vendas_vendedor);
```

## Por que usar

- **Legibilidade.** Uma consulta de cinco níveis de inline view vira uma sequência de etapas com nome, lidas de cima para baixo.
- **Reuso.** O mesmo bloco pode ser referenciado várias vezes. No exemplo, `vendas_vendedor` é usado no `FROM` e na subquery do `WHERE`.
- **Etapas que dependem umas das outras.** Um bloco do `WITH` pode usar os anteriores.

```sql
WITH itens_valor AS (...),
     pedidos_valor AS (SELECT ... FROM itens_valor ...),
     clientes_valor AS (SELECT ... FROM pedidos_valor ...)
SELECT ... FROM clientes_valor;
```

## Execução: inline ou materializado

O otimizador decide, para cada bloco, se o **incorpora** à consulta principal (como uma view) ou se o **materializa** numa tabela temporária e lê dali. Em geral, blocos usados uma vez são incorporados e blocos usados mais de uma vez podem ser materializados. Os hints `/*+ MATERIALIZE */` e `/*+ INLINE */`, colocados dentro do bloco, forçam uma das opções. Eles são muito usados, mas não constam da documentação oficial de hints; use quando o plano mostrar que a escolha automática foi ruim.

## WITH recursivo `[11gR2+]`

Um bloco que referencia a si mesmo percorre hierarquias e gera séries. É a forma do padrão SQL, alternativa ao `CONNECT BY` (tópico 09).

```sql
WITH org (id_funcionario, nome, nivel) AS (
    -- membro âncora: ponto de partida
    SELECT id_funcionario, nome, 1
      FROM funcionarios
     WHERE id_gerente IS NULL
    UNION ALL
    -- membro recursivo: junta a próxima camada ao que já foi encontrado
    SELECT f.id_funcionario, f.nome, o.nivel + 1
      FROM funcionarios f
      JOIN org o ON f.id_gerente = o.id_funcionario
)
SELECT * FROM org;
```

Regras:

- A lista de colunas depois do nome (`org (id_funcionario, nome, nivel)`) é **obrigatória** no Oracle.
- Âncora e parte recursiva são unidas por `UNION ALL`.
- O tipo de cada coluna vem da âncora. Texto que cresce a cada nível (um caminho, por exemplo) precisa de `CAST(... AS VARCHAR2(4000))` na âncora, senão o valor é cortado ou dá erro de tipo.
- `SEARCH DEPTH FIRST BY coluna SET ordem` (ou `BREADTH FIRST`) cria uma coluna para ordenar o resultado como árvore.
- `CYCLE coluna SET marca TO 'S' DEFAULT 'N'` detecta ciclos e para a recursão neles. Sem isso, um ciclo nos dados dá ORA-32044.

## WITH FUNCTION `[12c+]`

Permite declarar uma função PL/SQL dentro da própria consulta, sem criar objeto no banco:

```sql
WITH
  FUNCTION valor_liquido(p_qtd NUMBER, p_preco NUMBER, p_desc NUMBER) RETURN NUMBER IS
  BEGIN
      RETURN ROUND(p_qtd * p_preco * (1 - p_desc / 100), 2);
  END;
SELECT id_pedido, SUM(valor_liquido(quantidade, preco_unitario, pct_desconto))
  FROM itens_pedido
 GROUP BY id_pedido
/
```

No SQL*Plus e no SQLcl, um comando com `WITH FUNCTION` precisa terminar com `/` numa linha sozinha, porque o `;` dentro da função encerraria o comando antes da hora.

## Armadilhas

- **Nome de bloco igual ao de uma tabela** esconde a tabela dentro da consulta.
- **WITH não é tabela temporária permanente.** Só existe durante o comando.

## Documentação oficial

- [SQL Language Reference — SELECT (subquery_factoring_clause)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SELECT.html)
