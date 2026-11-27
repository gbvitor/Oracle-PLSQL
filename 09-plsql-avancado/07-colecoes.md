# Coleções: associative array, nested table e VARRAY

Coleção é uma variável com vários elementos do mesmo tipo, acessados por índice: `v_lista(3)`. É a base do processamento em lote (tópico 08) e de passar listas entre PL/SQL e SQL.

## Os três tipos

| | Associative array | Nested table | VARRAY |
|---|---|---|---|
| Declaração | `TABLE OF t INDEX BY PLS_INTEGER` (ou `VARCHAR2(n)`) | `TABLE OF t` | `VARRAY(n) OF t` |
| Índice | Inteiro qualquer (até negativo) ou texto | Inteiro a partir de 1 | Inteiro de 1 a n |
| Tamanho | Sem limite | Sem limite | Máximo fixo `n` |
| Precisa inicializar | Não | Sim: construtor `t_lista()` | Sim: construtor |
| Pode ter buracos | Sim, desde o início | Sim, depois de `DELETE(i)` | Não |
| Existe como tipo SQL (`CREATE TYPE`) | Não | Sim | Sim |
| Uso típico | Cache em memória, mapa chave → valor, `BULK COLLECT` | Listas passadas para SQL (`TABLE()`), operações de conjunto | Lista pequena de tamanho conhecido |

Na dúvida dentro de PL/SQL: **associative array**. Para mandar a lista para dentro de um SQL: **nested table** criada com `CREATE TYPE`.

## Métodos

| Método | Devolve / faz |
|---|---|
| `COUNT` | Quantidade de elementos existentes |
| `FIRST`, `LAST` | Menor e maior índice (NULL se vazia) |
| `NEXT(i)`, `PRIOR(i)` | Próximo e anterior índice existente (NULL no fim) |
| `EXISTS(i)` | Se o elemento i existe (não dá erro, mesmo em coleção vazia) |
| `EXTEND`, `EXTEND(n)` | Abre espaço no fim (nested table e VARRAY) |
| `TRIM`, `TRIM(n)` | Remove do fim (nested table e VARRAY) |
| `DELETE`, `DELETE(i)`, `DELETE(i, j)` | Remove tudo, um ou uma faixa (VARRAY só aceita `DELETE` sem argumento) |
| `LIMIT` | Máximo do VARRAY (NULL nos outros) |

## Percorrer

```sql
-- Só para coleção densa (sem buracos), como a que vem de BULK COLLECT
FOR i IN 1 .. v_lista.COUNT LOOP ... END LOOP;

-- Para qualquer coleção, inclusive esparsa ou indexada por texto
v_i := v_lista.FIRST;
WHILE v_i IS NOT NULL LOOP
    ...
    v_i := v_lista.NEXT(v_i);
END LOOP;
```

`FOR i IN 1 .. COUNT` em coleção com buraco lê um elemento inexistente e dá NO_DATA_FOUND. `FOR i IN FIRST .. LAST` falha com buraco pelo mesmo motivo e, em coleção **vazia**, dá VALUE_ERROR (ORA-06502): `FIRST` e `LAST` são NULL, e laço `FOR` com limite NULL é erro, não zero voltas. `1 .. COUNT` em coleção vazia é seguro (COUNT é 0).

Associative array indexado por texto é percorrido **em ordem de chave**, o que o torna um "mapa ordenado" útil para agrupar sem `ORDER BY`.

## Erros típicos

| Erro | Exceção | Causa |
|---|---|---|
| ORA-06531 | `COLLECTION_IS_NULL` | Usar nested table ou VARRAY sem chamar o construtor |
| ORA-06533 | `SUBSCRIPT_BEYOND_COUNT` | Índice maior que `COUNT` sem `EXTEND` antes |
| ORA-06532 | `SUBSCRIPT_OUTSIDE_LIMIT` | Índice fora de 1..limite do VARRAY, ou EXTEND além do limite |
| ORA-01403 | `NO_DATA_FOUND` | Ler elemento que não existe (associative array, ou excluído com DELETE) |

## Expressão qualificada `[18c+]`

```sql
v_mapa := t_mapa('SP' => 'São Paulo', 'TO' => 'Tocantins');
v_lista := t_lista(10, 20, 30);
```

Antes do 18c, associative array não tinha construtor; era preciso atribuir elemento por elemento.

## Coleções em SQL

Com o tipo criado por `CREATE TYPE ... AS TABLE OF`, a coleção vira tabela dentro da consulta:

```sql
CREATE TYPE t_ids AS TABLE OF NUMBER;

SELECT * FROM pedidos WHERE id_pedido IN (SELECT column_value FROM TABLE(:lista));
```

Operadores de conjunto sobre nested tables: `MULTISET UNION`, `MULTISET INTERSECT`, `MULTISET EXCEPT` (com `DISTINCT` opcional), `MEMBER OF`, `SUBMULTISET OF`, `CARDINALITY`, `SET()` (remove repetidos), `IS A SET`, `IS EMPTY`.

`TABLE()` também aceita coleção declarada em **package** a partir do 12c, usada dentro de PL/SQL.

## Documentação oficial

- [PL/SQL Language Reference — PL/SQL Collections and Records](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-collections-and-records.html)
- [PL/SQL Language Reference — Collection Methods](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-collections-and-records.html)
- [SQL Language Reference — Multiset Operators](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Multiset-Operators.html)
