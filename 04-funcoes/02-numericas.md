# Funções numéricas

## Referência

| Função | O que faz | Exemplo | Resultado |
|---|---|---|---|
| `ROUND(n [, d])` | Arredonda para `d` casas (meio para longe do zero) | `ROUND(2.345, 2)` / `ROUND(-2.5)` | `2.35` / `-3` |
| `ROUND(n, -d)` | Arredonda à esquerda da vírgula | `ROUND(1234, -2)` | `1200` |
| `TRUNC(n [, d])` | Corta sem arredondar | `TRUNC(2.349, 2)` | `2.34` |
| `CEIL(n)` | Menor inteiro maior ou igual | `CEIL(2.1)` / `CEIL(-2.1)` | `3` / `-2` |
| `FLOOR(n)` | Maior inteiro menor ou igual | `FLOOR(2.9)` / `FLOOR(-2.1)` | `2` / `-3` |
| `MOD(a, b)` | Resto, com o sinal de `a` | `MOD(11, 4)` / `MOD(-11, 4)` | `3` / `-3` |
| `REMAINDER(a, b)` | Resto em relação ao múltiplo **mais próximo** | `REMAINDER(11, 4)` | `-1` |
| `ABS(n)` | Valor absoluto | `ABS(-5)` | `5` |
| `SIGN(n)` | -1, 0 ou 1 | `SIGN(-5)` | `-1` |
| `POWER(a, b)` / `SQRT(n)` | Potência / raiz quadrada | `POWER(1.01, 12)` | `1.1268...` |
| `EXP(n)` / `LN(n)` / `LOG(b, n)` | Exponencial / logaritmo | `LOG(10, 1000)` | `3` |
| `WIDTH_BUCKET(n, min, max, faixas)` | Número da faixa em que `n` cai | `WIDTH_BUCKET(4500, 0, 10000, 4)` | `2` |

## ROUND, TRUNC, CEIL e FLOOR

| Valor | `ROUND` | `TRUNC` | `CEIL` | `FLOOR` |
|---|---|---|---|---|
| 2.5 | 3 | 2 | 3 | 2 |
| 2.4 | 2 | 2 | 3 | 2 |
| -2.5 | -3 | -2 | -2 | -3 |
| -2.4 | -2 | -2 | -2 | -3 |

`TRUNC` corta em direção ao zero; `FLOOR` vai sempre para baixo. A diferença só aparece em números negativos.

## Arredondamento em cálculos com várias linhas

Arredondar **cada linha** e somar não dá o mesmo que somar e arredondar **o total**. Em documento fiscal ou financeiro, a regra de onde arredondar é de negócio, não técnica: o schema de exemplo arredonda o valor de cada item (como faria uma nota fiscal) e soma os itens já arredondados.

Rateio é o caso clássico: dividir 100,00 em 3 parcelas dá 33,33 + 33,33 + 33,33 = 99,99. A diferença de centavo precisa ir para uma das parcelas (em geral a última).

## WIDTH_BUCKET

Divide o intervalo `[min, max)` em faixas de mesmo tamanho e diz em qual faixa o valor está. Valores abaixo de `min` vão para a faixa 0, e valores maiores ou iguais a `max` vão para `faixas + 1`. Útil para histogramas.

## Armadilhas

- **ROUND com BINARY_DOUBLE.** Os tipos de ponto flutuante seguem outras regras de representação; `ROUND` sobre eles pode não dar o resultado decimal esperado. Use `NUMBER` para valores que serão arredondados.
- **Divisão de inteiros.** Não existe: `7 / 2` = 3,5. Para parte inteira, `TRUNC(7 / 2)`.
- **MOD com negativo.** O sinal vem do dividendo. Para saber se um número é par, `MOD(n, 2) = 0` funciona com negativos; `MOD(n, 2) = 1` não reconhece ímpares negativos (dá -1).

## Documentação oficial

- [SQL Language Reference — Numeric Functions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Single-Row-Functions.html)
