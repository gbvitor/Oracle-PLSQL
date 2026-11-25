# MODEL (visão geral)

## O que é

A cláusula `MODEL` `[10g+]` trata o resultado de uma consulta como uma **planilha**: cada valor vira uma célula endereçável por dimensões, e regras calculam células novas ou alteram as existentes, inclusive com referência a outras células (`valor[2027] = valor[2026] * 1.10`).

É um recurso pouco usado. A maioria dos problemas que ele resolve tem solução mais legível com funções analíticas, `WITH` recursivo ou PL/SQL. Vale conhecer para reconhecer em código existente e para casos de projeção em que uma célula depende de outras calculadas antes.

## Estrutura

```sql
SELECT vendedor, ano, valor
  FROM (...)
 MODEL
     PARTITION BY (vendedor)     -- planilhas independentes, uma por vendedor
     DIMENSION BY (ano)          -- o "endereço" de cada célula
     MEASURES (valor)            -- o conteúdo das células
     RULES (
         valor[2027] = ROUND(valor[2026] * 1.10, 2),
         valor[2028] = ROUND(valor[2027] * 1.10, 2)
     );
```

| Parte | Papel |
|---|---|
| `PARTITION BY` | Divide em blocos calculados separadamente; regras não cruzam partições |
| `DIMENSION BY` | Colunas que identificam a célula (como linha e coluna de uma planilha) |
| `MEASURES` | Colunas com valores que as regras leem e escrevem |
| `RULES` | Atribuições. Por padrão `UPSERT`: atualiza a célula se existir, cria se não existir |

## Recursos das regras

- **Referência posicional**: `valor[2026]`. **Simbólica**: `valor[ano = 2026]`.
- **Intervalos e curingas**: `valor[ano BETWEEN 2025 AND 2026]`, `valor[ANY]`.
- **`CV()`**: o valor atual da dimensão no lado esquerdo, para regras relativas: `valor[ano > 2026] = valor[CV(ano) - 1] * 1.10`.
- **`ITERATE (n)`**: repete as regras n vezes, para cálculos convergentes.
- **`RULES AUTOMATIC ORDER`**: o Oracle ordena as regras pelas dependências; o padrão é `SEQUENTIAL ORDER` (na ordem escrita).
- **`RETURN UPDATED ROWS`**: devolve só as células criadas ou alteradas.

## Documentação oficial

- [Data Warehousing Guide — SQL for Modeling](https://docs.oracle.com/en/database/oracle/oracle-database/19/dwhsg/sql-modeling-data-warehouses.html)
