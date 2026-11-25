# AND, OR, NOT, IS NULL e parênteses

Este tópico reúne as condições lógicas. O comportamento do NULL em detalhe está na seção 01, tópico 04; aqui o foco é montar condições compostas corretas.

## Tabelas-verdade com NULL

Com NULL, uma condição pode ser TRUE, FALSE ou UNKNOWN (desconhecida).

| A | B | A AND B | A OR B |
|---|---|---|---|
| TRUE | UNKNOWN | UNKNOWN | TRUE |
| FALSE | UNKNOWN | FALSE | UNKNOWN |
| UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN |

`NOT TRUE` = FALSE, `NOT FALSE` = TRUE, **`NOT UNKNOWN` = UNKNOWN**.

Consequência: `NOT (pct_comissao > 3)` não devolve "todos os que não têm comissão acima de 3". Quem tem comissão nula fica de fora dos dois lados, porque `pct_comissao > 3` é UNKNOWN e a negação continua UNKNOWN.

## IS NULL e IS NOT NULL

São as únicas condições que testam NULL diretamente, e nunca devolvem UNKNOWN.

| Forma | Uso |
|---|---|
| `coluna IS NULL` | A coluna não tem valor |
| `coluna IS NOT NULL` | Tem valor |
| `LNNVL(condição)` | Verdadeiro se a condição for FALSE **ou** UNKNOWN. Útil para negar sem perder os nulos: `LNNVL(pct_comissao > 3)` |

## Precedência

`NOT` antes de `AND`, `AND` antes de `OR`. Na dúvida, parênteses.

```sql
-- Errado: lido como  a OR (b AND c)
WHERE status = 'ABERTO' OR status = 'FATURADO' AND id_cliente = 1

-- Certo
WHERE (status = 'ABERTO' OR status = 'FATURADO') AND id_cliente = 1
```

## Leis de De Morgan

Úteis para reescrever negações:

- `NOT (A AND B)` = `NOT A OR NOT B`
- `NOT (A OR B)` = `NOT A AND NOT B`

Exemplo: "nem SP nem MG" = `NOT (uf = 'SP' OR uf = 'MG')` = `uf <> 'SP' AND uf <> 'MG'` = `uf NOT IN ('SP', 'MG')`.

Valem também com NULL: as duas formas dão o mesmo resultado, inclusive UNKNOWN.

## Armadilhas

- **Negar uma condição sobre coluna que aceita NULL** perde as linhas nulas. Decida se elas entram e escreva `OR coluna IS NULL`, ou use `LNNVL`.
- **`OR` misturado com `AND` sem parênteses.**
- **Comparar com NULL usando `=`.** `WHERE coluna = NULL` nunca é verdadeiro e não dá erro.

## Documentação oficial

- [SQL Language Reference — Logical Conditions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Logical-Conditions.html)
- [SQL Language Reference — Null Conditions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Null-Conditions.html)
