# WHERE

## O que faz

Filtra as linhas vindas do `FROM`: só passam as linhas em que a condição é **verdadeira**. Linhas em que ela é falsa ou desconhecida (NULL) ficam de fora. Os operadores e condições disponíveis estão na seção 03; aqui o foco é como montar o filtro.

```sql
SELECT id_pedido, data_pedido, status
  FROM pedidos
 WHERE status = 'ENTREGUE'
   AND data_pedido >= DATE '2026-01-01';
```

## Precedência: AND antes de OR

`AND` é avaliado antes de `OR`, como multiplicação antes de soma.

```sql
-- Lido como: status = 'ENTREGUE' OR (status = 'FATURADO' AND id_cliente = 1)
WHERE status = 'ENTREGUE' OR status = 'FATURADO' AND id_cliente = 1

-- O que normalmente se quer:
WHERE (status = 'ENTREGUE' OR status = 'FATURADO') AND id_cliente = 1

-- Mais legível ainda:
WHERE status IN ('ENTREGUE', 'FATURADO') AND id_cliente = 1
```

Sempre que `AND` e `OR` aparecem juntos, use parênteses, mesmo quando a precedência já daria o resultado certo.

## Filtro por data

`DATE` sempre tem hora. O padrão seguro para um período é o **intervalo semiaberto**: maior ou igual ao início, menor que o dia seguinte ao fim.

```sql
-- Outubro de 2026 inteiro, qualquer hora
WHERE data_pedido >= DATE '2026-10-01'
  AND data_pedido <  DATE '2026-11-01'
```

`BETWEEN DATE '2026-10-01' AND DATE '2026-10-31'` perde tudo o que aconteceu no dia 31 depois de 00:00:00. `TRUNC(data_pedido) BETWEEN ...` acerta o resultado, mas aplica função na coluna (ver abaixo).

## Filtro que usa índice

O Oracle só usa um índice comum sobre a coluna se o filtro comparar **a coluna pura** com um valor. Qualquer função ou conversão aplicada à coluna obriga a calcular a expressão linha a linha:

| Impede o índice | Alternativa que preserva |
|---|---|
| `WHERE TRUNC(data_pedido) = DATE '2026-10-14'` | `WHERE data_pedido >= DATE '2026-10-14' AND data_pedido < DATE '2026-10-15'` |
| `WHERE UPPER(nome) = 'ANA RIBEIRO'` | Índice baseado em função `UPPER(nome)` (seção 07) |
| `WHERE salario * 12 > 100000` | `WHERE salario > 100000 / 12` |
| `WHERE documento = 10000000000101` (número contra texto) | `WHERE documento = '10000000000101'` |
| `WHERE NVL(id_vendedor, 0) = 0` | `WHERE id_vendedor IS NULL` |

## Conversão implícita

Comparar coluna de texto com número faz o Oracle converter **a coluna** para número (`TO_NUMBER(documento) = 10000000000101`). Além de impedir o índice, a consulta quebra com ORA-01722 (número inválido) no dia em que aparecer um documento com caractere não numérico. Compare sempre com o tipo da coluna.

## Ordem de avaliação

O Oracle não garante a ordem em que as condições do `WHERE` são avaliadas nem que pare na primeira falsa. Código que depende disso falha de forma intermitente:

```sql
-- Pode dar ORA-01722 mesmo com o primeiro filtro: nada garante que ele roda antes.
WHERE tipo_pessoa = 'J' AND TO_NUMBER(documento) > 10000000000103
```

Quando a ordem importa, use `CASE`, que é avaliado em ordem: `WHERE CASE WHEN tipo_pessoa = 'J' THEN TO_NUMBER(documento) END > 10000000000103`.

## Documentação oficial

- [SQL Language Reference — Conditions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Conditions.html)
