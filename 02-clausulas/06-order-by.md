# ORDER BY

## Sintaxe

```sql
ORDER BY expressao [ ASC | DESC ] [ NULLS FIRST | NULLS LAST ] [, ...]
```

- `ASC` (padrão) ou `DESC` vale para cada expressão separadamente.
- NULL fica **por último** em `ASC` e **primeiro** em `DESC`. `NULLS FIRST` / `NULLS LAST` muda isso.
- Pode ordenar por coluna, expressão, alias do `SELECT` ou posição (`ORDER BY 2`).
- Pode ordenar por coluna que não está no `SELECT`, exceto com `DISTINCT`, `GROUP BY` (precisa ser coluna agrupada ou agregação) e operadores de conjunto (`UNION`...), que só aceitam colunas do resultado.

## Sem ORDER BY, sem ordem

Uma consulta sem `ORDER BY` devolve as linhas **em qualquer ordem**. Hoje pode sair na ordem de inserção, amanhã, depois de um índice novo, de uma estatística atualizada ou de execução paralela, não. `GROUP BY` e `DISTINCT` também não garantem ordem desde o 10g. Se a ordem importa, ela precisa estar escrita.

## Desempate

Se duas linhas empatam em todas as expressões do `ORDER BY`, a ordem entre elas é imprevisível e pode mudar de uma execução para outra. Em paginação isso é grave: a mesma linha aparece em duas páginas e outra some. Termine o `ORDER BY` com uma coluna única (a chave primária).

```sql
ORDER BY data_cadastro DESC, id_cliente
```

## Ordem personalizada

Para uma ordem de negócio que não é alfabética, `CASE` no `ORDER BY`:

```sql
ORDER BY CASE status
             WHEN 'ABERTO'    THEN 1
             WHEN 'FATURADO'  THEN 2
             WHEN 'ENTREGUE'  THEN 3
             WHEN 'CANCELADO' THEN 4
         END
```

## Ordenação de texto

Por padrão (`NLS_SORT = BINARY`), o texto é ordenado pelo código do caractere: maiúsculas antes de minúsculas, e letras acentuadas depois do `z`. Para ordenar como num dicionário:

```sql
ORDER BY NLSSORT(nome, 'NLS_SORT = BINARY_AI')   -- ignora maiúsculas e acentos
```

ou `ALTER SESSION SET NLS_SORT = BINARY_CI` (ignora maiúsculas) / `BINARY_AI` (ignora maiúsculas e acentos), que afeta todas as ordenações da sessão.

## ORDER SIBLINGS BY

Em consulta hierárquica com `CONNECT BY`, um `ORDER BY` comum desmonta a árvore. `ORDER SIBLINGS BY` ordena só os irmãos dentro de cada nível, preservando a hierarquia (tópico 09).

## Armadilhas

- **`ORDER BY 2`** depende da posição da coluna: incluir uma coluna no `SELECT` muda a ordenação sem erro. Use em consulta ad hoc, não em código que fica.
- **`ORDER BY` dentro de inline view** não garante a ordem da consulta de fora.
- **Ordenar número guardado como texto** dá `1, 10, 2`. Ordene pela conversão ou guarde no tipo certo.
- **Ordenar por data formatada** com `TO_CHAR(data, 'DD/MM/YYYY')` ordena pelo dia, não pela data.

## Documentação oficial

- [SQL Language Reference — SELECT (order_by_clause)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SELECT.html)
- [Globalization Support Guide — Linguistic Sorting](https://docs.oracle.com/en/database/oracle/oracle-database/19/nlspg/linguistic-sorting-and-matching.html)
