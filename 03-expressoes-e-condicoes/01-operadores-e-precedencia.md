# Operadores aritméticos, concatenação e precedência

## Operadores

| Operador | Operação | Exemplo | Resultado |
|---|---|---|---|
| `+` `-` (unários) | Sinal | `-salario` | |
| `*` | Multiplicação | `quantidade * preco_unitario` | |
| `/` | Divisão | `7 / 2` | `3.5` (não existe divisão inteira) |
| `+` | Soma | `salario + 100` | |
| `-` | Subtração | `DATE '2026-03-01' - DATE '2026-02-01'` | `28` (dias) |
| `\|\|` | Concatenação de texto | `nome \|\| ' - ' \|\| cargo` | |

Para o resto e a parte inteira da divisão, há funções: `MOD(7, 2)` = 1, `TRUNC(7 / 2)` = 3. Divisão por zero dá ORA-01476.

## Precedência

Da mais alta para a mais baixa:

| Nível | Operadores |
|---|---|
| 1 | `+` `-` unários, `PRIOR`, `CONNECT_BY_ROOT`, `COLLATE` |
| 2 | `*` `/` |
| 3 | `+` `-` binários **e** `\|\|` |

Operadores do mesmo nível são avaliados **da esquerda para a direita**. Parênteses mudam a ordem.

## A armadilha da concatenação

`+`, `-` e `||` têm a **mesma precedência**. Por isso:

```sql
SELECT 'Total: ' || 10 + 5 FROM dual;
```

é lido como `('Total: ' || 10) + 5`, ou seja, `'Total: 10' + 5`, e falha com ORA-01722 ao tentar converter o texto em número. O correto é `'Total: ' || (10 + 5)`. A documentação da Oracle avisa que uma versão futura pode dar ao `||` precedência menor; parênteses tornam o código correto em qualquer caso.

## NULL nas operações

- Aritmética com NULL dá NULL: `salario + NULL` é NULL.
- Concatenação ignora NULL: `'abc' || NULL` é `'abc'`. É particularidade do Oracle, ligada a `''` ser NULL.
- `CONCAT(a, b)` faz o mesmo que `a || b`, mas aceita só dois argumentos.

## Número virando texto

Na concatenação, o número é convertido com o formato padrão, que **não** coloca zero antes do separador decimal nem casas fixas, e usa o separador definido em `NLS_NUMERIC_CHARACTERS` da sessão:

| Expressão | Sessão com `'.,'` | Sessão com `',.'` |
|---|---|---|
| `'Taxa: ' \|\| 0.5` | `Taxa: .5` | `Taxa: ,5` |
| `'Valor: ' \|\| 10.50` | `Valor: 10.5` | `Valor: 10,5` |
| `'Valor: ' \|\| TO_CHAR(10.5, 'FM999G990D00')` | `Valor: 10.50` | `Valor: 10,50` |

Para texto que alguém vai ler, formate com `TO_CHAR` (seção 04).

## Documentação oficial

- [SQL Language Reference — Operators](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Operators.html)
