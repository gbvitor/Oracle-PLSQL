# Funções para tratar NULL

## Referência

| Função | Devolve | Exemplo | Resultado |
|---|---|---|---|
| `NVL(a, b)` | `a` se não for nulo; senão `b` | `NVL(pct_comissao, 0)` | 0 para quem não tem comissão |
| `NVL2(a, b, c)` | `b` se `a` **não** for nulo; `c` se for | `NVL2(email, 'tem', 'nao tem')` | |
| `COALESCE(a, b, c, ...)` | O primeiro valor não nulo da lista | `COALESCE(email, telefone, 'sem contato')` | |
| `NULLIF(a, b)` | NULL se `a = b`; senão `a` | `NULLIF(divisor, 0)` | Evita divisão por zero |
| `LNNVL(condição)` | TRUE se a condição for FALSE ou UNKNOWN | `LNNVL(pct_comissao > 3)` | Inclui os nulos |
| `DECODE(a, NULL, x, y)` | Compara com NULL como se fosse valor | | Seção 03, tópico 03 |

## NVL ou COALESCE

| | `NVL` | `COALESCE` |
|---|---|---|
| Argumentos | Exatamente 2 | 2 ou mais |
| Avaliação | **Avalia os dois sempre** | Para no primeiro não nulo |
| Tipos diferentes | Converte o segundo para o tipo do primeiro | Exige tipos compatíveis (ORA-00932) |
| Padrão SQL | Não (Oracle) | Sim |

A diferença de avaliação importa quando o segundo argumento é caro (uma função, uma subquery) ou pode dar erro: `NVL(coluna, funcao_lenta())` chama a função em toda linha, inclusive quando a coluna tem valor. `COALESCE` não chama.

A conversão do `NVL` também engana: `NVL(pct_comissao, 'sem comissao')` tenta converter o texto em número e dá ORA-01722. Para mostrar texto no lugar de um número nulo: `NVL(TO_CHAR(pct_comissao), 'sem comissao')`.

## NULLIF

Usos típicos:

- **Divisão segura**: `valor / NULLIF(quantidade, 0)` devolve NULL em vez de ORA-01476.
- **Transformar valor "vazio" em NULL**: `NULLIF(TRIM(observacao), '-')` trata `'-'` como ausência de valor.

O primeiro argumento não pode ser o literal `NULL`.

## Quando NÃO trocar NULL por zero

`NVL(coluna, 0)` muda a pergunta. A média de comissão de quem tem comissão é 3,8; a média com nulos virando zero é 1,36. As duas estão certas, mas para perguntas diferentes. Em relatório, o NULL costuma significar "não se aplica" ou "não informado", e esconder isso com zero apaga uma informação.

## Documentação oficial

- [SQL Language Reference — NULL-Related Functions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Single-Row-Functions.html)
