# Curva ABC de produtos

## Cenário

Classificar os produtos pela participação no faturamento: classe **A** (os poucos que fazem a maior parte da venda), **B** (intermediários) e **C** (a cauda longa). Uso típico: definir política de estoque, prioridade de negociação com fornecedor, atenção comercial.

Regra usada aqui (a mais comum; os cortes variam por empresa):

| Classe | Faixa do percentual **acumulado** |
|---|---|
| A | Até 80% |
| B | Acima de 80% até 95% |
| C | Acima de 95%, e produtos sem venda |

## A consulta, em quatro camadas

1. Valor vendido por produto no período, com **LEFT JOIN** a partir de `produtos` (produto sem venda entra com zero e vai para C).
2. Percentual de cada um: `valor / SUM(valor) OVER ()`.
3. Acumulado em ordem decrescente: `SUM(valor) OVER (ORDER BY valor DESC, id_produto ROWS UNBOUNDED PRECEDING)`.
4. Classe por `CASE` sobre o acumulado.

## Decisões que mudam o resultado

- **Critério de corte**: comparar o acumulado *depois* do produto (`<= 80`) ou *antes* dele (`acumulado - valor < 80`). No segundo, o produto que "cruza" os 80% entra em A. Os dois são usados; o script mostra a diferença, que aqui muda a classe de dois produtos.
- **Desempate**: produtos com o mesmo valor precisam de um segundo critério (`id_produto`) na janela, com `ROWS`, senão o acumulado deles sai igual (janela `RANGE` padrão) e a classe pode depender da ordem de leitura.
- **Medida**: faturamento, margem, quantidade ou frequência de venda dão curvas diferentes. A curva de estoque costuma usar **custo** da quantidade movimentada.
- **Período**: 12 meses móveis é o usual; a curva de um mês só reflete sazonalidade.

## Documentação oficial

- [SQL Language Reference — Analytic Functions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Analytic-Functions.html)
- [SQL Language Reference — RATIO_TO_REPORT](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/RATIO_TO_REPORT.html)
