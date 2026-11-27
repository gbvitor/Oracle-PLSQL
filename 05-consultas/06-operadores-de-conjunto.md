# Operadores de conjunto: UNION, UNION ALL, INTERSECT, MINUS

## Operadores

| Operador | Resultado | Remove repetidos |
|---|---|---|
| `UNION` | Linhas de A ou de B | Sim |
| `UNION ALL` | Linhas de A seguidas das de B | **Não** |
| `INTERSECT` | Linhas que estão em A e em B | Sim |
| `MINUS` | Linhas de A que não estão em B | Sim |
| `EXCEPT` `[21c+]` | Sinônimo de `MINUS` (nome do padrão SQL) | Sim |
| `INTERSECT ALL`, `MINUS ALL`, `EXCEPT ALL` `[21c+]` | Versões que consideram repetições | Não |

## Regras

- Os dois `SELECT` precisam ter **o mesmo número de colunas** com **tipos compatíveis**, na mesma ordem. Os nomes não precisam coincidir.
- Os nomes das colunas do resultado vêm do **primeiro** `SELECT`.
- `ORDER BY` só no fim, valendo para o resultado combinado; pode usar posição ou alias/nome do primeiro `SELECT`.
- Nas comparações dos operadores de conjunto, **NULL é igual a NULL**: duas linhas `(1, NULL)` são consideradas repetidas. É diferente do `=` do `WHERE`.
- Todos têm a mesma precedência e são avaliados da esquerda para a direita. Use parênteses ao misturar.

## UNION ou UNION ALL

`UNION` precisa ordenar ou agrupar para eliminar repetidos: custa mais e pode esconder linhas que deveriam aparecer duas vezes. Use `UNION ALL` sempre que:

- os conjuntos não podem se repetir (dados de tabelas ou períodos diferentes), ou
- as repetições devem aparecer (somar movimentos de duas origens).

`UNION` só quando a eliminação de repetidos é parte da pergunta.

## Usos

| Pergunta | Operador |
|---|---|
| Juntar listas de origens diferentes num relatório | `UNION ALL` |
| Clientes que compraram em 2025 **e** em 2026 | `INTERSECT` |
| Clientes que compraram em 2025 e **não** em 2026 | `MINUS` |
| Diferenças entre duas tabelas (origem × destino de uma carga) | `(A MINUS B) UNION ALL (B MINUS A)` |
| Tabela de valores fixos | `SELECT ... FROM dual UNION ALL SELECT ... FROM dual` |

A comparação de tabelas com `MINUS` nos dois sentidos é uma das formas mais simples de conferir se uma migração ou integração copiou tudo, e é usada na seção 15.

## Armadilhas

- **`UNION` quando se queria somar**: dois lançamentos iguais em origens diferentes viram um só.
- **Ordem das colunas trocada**: `SELECT nome, cidade ... UNION ALL SELECT cidade, nome ...` funciona (os tipos são iguais) e mistura as colunas sem erro.
- **`ORDER BY` no meio**: só é permitido dentro de uma subquery entre parênteses, e não garante a ordem do resultado final.

## Documentação oficial

- [SQL Language Reference — The UNION [ALL], INTERSECT, MINUS Operators](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/The-UNION-ALL-INTERSECT-MINUS-Operators.html)
