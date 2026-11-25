# FETCH FIRST e OFFSET

## Sintaxe `[12c+]`

```sql
SELECT ...
  FROM ...
 ORDER BY ...
[ OFFSET n { ROW | ROWS } ]
[ FETCH { FIRST | NEXT } [ n | p PERCENT ] { ROW | ROWS } { ONLY | WITH TIES } ]
```

| Forma | O que devolve |
|---|---|
| `FETCH FIRST 5 ROWS ONLY` | As 5 primeiras linhas na ordem do `ORDER BY` |
| `FETCH FIRST 5 ROWS WITH TIES` | As 5 primeiras e mais as que empatam com a 5ª |
| `FETCH FIRST 10 PERCENT ROWS ONLY` | 10% das linhas, arredondado para cima |
| `OFFSET 10 ROWS FETCH NEXT 10 ROWS ONLY` | Pula 10, devolve as 10 seguintes (página 2 de 10 em 10) |
| `OFFSET 10 ROWS` | Pula 10 e devolve todo o resto |

`FIRST`/`NEXT` e `ROW`/`ROWS` são intercambiáveis; existem para a frase soar natural.

O corte acontece **depois** do `ORDER BY`. Sem `ORDER BY`, as "primeiras" linhas são quaisquer linhas.

## WITH TIES

Exige `ORDER BY`. Se o 2º e o 3º colocados empatam, `FETCH FIRST 2 ROWS WITH TIES` devolve 3 linhas. É a forma direta de responder "os N maiores, incluindo empates".

## Paginação

```sql
-- Página p, com t linhas por página
OFFSET (p - 1) * t ROWS FETCH NEXT t ROWS ONLY
```

Dois cuidados:

1. **Ordem determinística.** O `ORDER BY` precisa terminar numa coluna única, senão a mesma linha pode aparecer em duas páginas (tópico 06).
2. **Custo do OFFSET.** Para entregar a página 1000, o banco lê e descarta as 999 anteriores. Em listas grandes, a **paginação por chave** (keyset) é muito mais barata: em vez de "pular N", filtra a partir do último valor visto.

```sql
-- Próxima página depois do pedido 1010
WHERE id_pedido > 1010
ORDER BY id_pedido
FETCH FIRST 5 ROWS ONLY
```

A paginação por chave não permite saltar direto para a página 37, mas tem custo constante e não pula nem repete linhas quando há inserções entre uma página e outra.

## Antes do 12c `[legado]`

```sql
-- Top-N
SELECT * FROM (SELECT ... ORDER BY ...) WHERE ROWNUM <= 5;

-- Página 2 de 5 em 5
SELECT *
  FROM (SELECT v.*, ROWNUM AS rn
          FROM (SELECT ... ORDER BY ...) v
         WHERE ROWNUM <= 10)
 WHERE rn > 5;
```

O Oracle reescreve internamente o `FETCH FIRST` com `ROW_NUMBER()`; o desempenho dos dois é equivalente. Ainda é comum encontrar o padrão com `ROWNUM` em código existente.

## Armadilhas

- **`FETCH FIRST` sem `ORDER BY`.** Válido, e devolve linhas arbitrárias.
- **Top-N por grupo** ("os 2 maiores pedidos de cada cliente") não se resolve com `FETCH FIRST`, que corta o resultado inteiro. Use `ROW_NUMBER()` particionado (seção 05) ou `LATERAL` (tópico 02).
- **`FETCH` dentro de subquery no `WHERE`** é permitido, mas se a subquery for correlacionada o custo se repete por linha.

## Documentação oficial

- [SQL Language Reference — SELECT (row_limiting_clause)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SELECT.html)
