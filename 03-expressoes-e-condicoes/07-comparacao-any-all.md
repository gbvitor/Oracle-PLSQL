# Condições de comparação: =, <>, ANY, SOME, ALL

## Operadores

| Operador | Significado |
|---|---|
| `=` | Igual |
| `<>`, `!=`, `^=` | Diferente (os três são equivalentes; `<>` é o padrão SQL) |
| `<`, `>`, `<=`, `>=` | Menor, maior, menor ou igual, maior ou igual |

Valem para número, texto e data. Texto é comparado pelo valor binário dos caracteres (ou pela regra linguística, se `NLS_COMP = LINGUISTIC`), então `'a' > 'Z'` é verdadeiro. Qualquer comparação com NULL é desconhecida (seção 01, tópico 04).

## ANY / SOME e ALL

Comparam um valor com **uma lista** ou com o resultado de uma subquery. `SOME` é sinônimo de `ANY`.

| Condição | Verdadeira quando | Equivale a |
|---|---|---|
| `x > ANY (lista)` | `x` é maior que **pelo menos um** item | `x > MIN(lista)` |
| `x > ALL (lista)` | `x` é maior que **todos** os itens | `x > MAX(lista)` |
| `x = ANY (lista)` | `x` é igual a algum item | `x IN (lista)` |
| `x <> ALL (lista)` | `x` é diferente de todos | `x NOT IN (lista)` |

```sql
-- Funcionários que ganham mais que qualquer vendedor
WHERE salario > ALL (SELECT salario FROM funcionarios WHERE cargo = 'Vendedor')
```

## Lista vazia

| Condição | Com lista vazia |
|---|---|
| `x > ALL (vazia)` | **Verdadeiro** para toda linha |
| `x > ANY (vazia)` | **Falso** para toda linha |

A diferença em relação a `x > (SELECT MAX(...))` é exatamente essa: `MAX` de conjunto vazio é NULL, e `x > NULL` é desconhecido (nenhuma linha). Com `ALL`, todas as linhas passam. Escolha conforme o que a regra de negócio espera quando não há referência.

## NULL na lista

- `x > ALL (lista com NULL)`: nunca verdadeiro, porque a comparação com o NULL é desconhecida.
- `x <> ALL (lista com NULL)`: o mesmo problema do `NOT IN` (tópico 09).
- `x > ANY (lista com NULL)`: funciona se houver algum valor não nulo que satisfaça.

## Quando usar

`ANY`/`ALL` são pouco usados na prática; `MIN`/`MAX`, `IN` e `EXISTS` costumam ser mais claros. Vale conhecer para ler código e pelo comportamento com lista vazia.

## Documentação oficial

- [SQL Language Reference — Comparison Conditions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Comparison-Conditions.html)
