# Sintaxe de join antiga com (+) `[legado]`

## Como funciona

Antes da sintaxe ANSI (`JOIN ... ON`, disponível no Oracle desde o 9i), joins eram escritos com as tabelas separadas por vírgula e a condição no `WHERE`. O outer join era indicado com `(+)` **do lado da tabela opcional**, ou seja, do lado que pode não ter par e receberá NULL.

```sql
-- Inner join
SELECT c.nome, p.id_pedido
  FROM clientes c, pedidos p
 WHERE p.id_cliente = c.id_cliente;

-- Left join: todos os clientes; pedidos opcionais
SELECT c.nome, p.id_pedido
  FROM clientes c, pedidos p
 WHERE p.id_cliente (+) = c.id_cliente;
```

O `(+)` fica junto da coluna de `pedidos` porque é `pedidos` que pode faltar.

## Filtros sobre a tabela opcional

Toda condição sobre a tabela opcional precisa do `(+)`. Sem ele, a condição é aplicada depois do join e transforma o outer em inner, o mesmo efeito de pôr a condição no `WHERE` em vez do `ON` na sintaxe ANSI.

```sql
-- Equivale a LEFT JOIN pedidos p ON p.id_cliente = c.id_cliente AND p.status = 'ABERTO'
WHERE p.id_cliente (+) = c.id_cliente
  AND p.status     (+) = 'ABERTO'
```

## Limitações

- Não há forma de escrever **FULL OUTER JOIN** com `(+)`. O contorno era `UNION` de um left e um right.
- `(+)` não pode ser usado com `OR` nem com `IN` contra subquery (ORA-01719).
- Uma tabela não pode ser lado opcional de duas tabelas diferentes no mesmo nível (ORA-01417, relaxado em versões recentes).
- O `(+)` só se aplica a colunas, não a expressões inteiras de forma intuitiva, o que gera erros sutis.

## Por que ainda importa

Muito código Oracle existente (views de sistemas, relatórios antigos, objetos de ERP) usa essa forma. Ler e converter com segurança é a habilidade necessária:

| Antigo | ANSI |
|---|---|
| `FROM a, b WHERE b.x = a.x` | `FROM a JOIN b ON b.x = a.x` |
| `FROM a, b WHERE b.x (+) = a.x` | `FROM a LEFT JOIN b ON b.x = a.x` |
| `... AND b.y (+) = 'K'` | `... ON b.x = a.x AND b.y = 'K'` |
| `... AND b.y = 'K'` (sem `+`) | `... WHERE b.y = 'K'` (vira inner) |

Na conversão, preste atenção a cada condição sobre a tabela opcional: com `(+)` ela vai para o `ON`; sem `(+)`, vai para o `WHERE` e muda o tipo do join. Muitas vezes o código antigo tinha um "bug" que só aparece na conversão.

## Documentação oficial

- [SQL Language Reference — Joins (Outer Joins)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Joins.html)
