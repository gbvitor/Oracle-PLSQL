# BETWEEN

## Sintaxe

```sql
x [NOT] BETWEEN limite_inferior AND limite_superior
```

Equivale a `x >= limite_inferior AND x <= limite_superior`: **os dois limites estão incluídos**.

## Regras

- **A ordem importa.** `BETWEEN 10 AND 5` é `x >= 10 AND x <= 5`, que nunca é verdadeiro. Não há erro: só nenhuma linha.
- `NOT BETWEEN a AND b` equivale a `x < a OR x > b`.
- Se `x` ou algum limite for NULL, o resultado é UNKNOWN.

## Com datas

`DATE` tem hora. `BETWEEN DATE '2026-10-01' AND DATE '2026-10-31'` vai até **31/10 às 00:00:00** e perde todo o resto do dia 31. As alternativas:

| Forma | Avaliação |
|---|---|
| `data >= DATE '2026-10-01' AND data < DATE '2026-11-01'` | Correta, usa índice. **Padrão recomendado** |
| `TRUNC(data) BETWEEN DATE '2026-10-01' AND DATE '2026-10-31'` | Correta, mas impede o índice comum em `data` |
| `data BETWEEN DATE '2026-10-01' AND DATE '2026-10-31' + 86399/86400` | Correta para `DATE`; falha com `TIMESTAMP` (frações de segundo) e é difícil de ler |

## Com texto

Comparação binária, caractere a caractere. `nome BETWEEN 'A' AND 'C'` inclui "Ana" e "Bruno", mas **não** "Carla": "Carla" é maior que "C" (tem mais caracteres depois do C). Para "nomes que começam de A a C": `nome >= 'A' AND nome < 'D'`.

## Quando usar

Faixas numéricas fechadas nos dois lados (salário de 4300 a 5200, nota de 0 a 10). Para datas e texto, o intervalo semiaberto (`>=` e `<`) é mais seguro.

## Documentação oficial

- [SQL Language Reference — BETWEEN Condition](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/BETWEEN-Condition.html)
