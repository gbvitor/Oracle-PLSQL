# Lacunas e sequências (gaps and islands)

## O problema

Numa série ordenada (números, datas, meses), encontrar:

- **ilhas**: trechos contínuos ("meses seguidos com venda", "dias seguidos com o equipamento parado");
- **lacunas**: o que falta entre eles ("numeração de nota pulada", "meses sem venda").

## Ilhas: a diferença constante

Se os valores são consecutivos, **valor − número da linha** é constante dentro de cada trecho contínuo e muda quando há um salto:

| Mês (índice) | ROW_NUMBER | Diferença |
|---|---|---|
| 1 | 1 | 0 |
| 2 | 2 | 0 |
| 3 | 3 | 0 |
| 5 | 4 | 1 |
| 6 | 5 | 1 |

A diferença vira um identificador de grupo; um `GROUP BY` por ela dá início, fim e tamanho de cada ilha.

```sql
SELECT MIN(valor) AS inicio, MAX(valor) AS fim, COUNT(*) AS tamanho
  FROM (SELECT valor, valor - ROW_NUMBER() OVER (ORDER BY valor) AS grupo FROM serie)
 GROUP BY grupo;
```

Para datas diárias, `data - ROW_NUMBER()` funciona direto (subtrair número de `DATE` tira dias). Para meses, converta antes para um índice inteiro: `ano * 12 + mês`.

Se a série pode ter valores repetidos, use `DENSE_RANK` no lugar de `ROW_NUMBER`.

## Lacunas: LEAD

Para cada valor, o próximo da série com `LEAD`; quando a diferença é maior que um passo, existe uma lacuna entre eles:

```sql
SELECT valor + 1 AS lacuna_inicio, proximo - 1 AS lacuna_fim
  FROM (SELECT valor, LEAD(valor) OVER (ORDER BY valor) AS proximo FROM serie)
 WHERE proximo - valor > 1;
```

## Ilhas por mudança de estado

Outra variação: trechos em que uma coluna mantém o mesmo valor ("períodos em que o status ficou igual"). Marque com 1 cada linha em que o valor muda em relação à anterior (`LAG`) e faça a soma acumulada dessas marcas: o resultado é o número do trecho.

```sql
SUM(CASE WHEN status = LAG(status) OVER (ORDER BY data) THEN 0 ELSE 1 END)
    OVER (ORDER BY data ROWS UNBOUNDED PRECEDING) AS trecho
```

`MATCH_RECOGNIZE` (seção 02, tópico 14) resolve todos esses casos com outra sintaxe.

## Documentação oficial

- [SQL Language Reference — Analytic Functions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Analytic-Functions.html)
