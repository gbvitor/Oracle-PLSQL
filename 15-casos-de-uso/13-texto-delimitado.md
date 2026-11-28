# Quebrar texto delimitado em linhas e juntar linhas em texto

## Cenário

Dois problemas inversos que aparecem o tempo todo:

- **Quebrar**: uma coluna ou parâmetro traz vários valores num texto (`'2;5;6'`, `'SP,TO'`), e é preciso tratá-los como linhas: juntar com outra tabela, usar num `IN`, contar.
- **Juntar**: várias linhas precisam virar um texto (`'Campinas, Sao Paulo'`) para relatório, e-mail ou integração.

Guardar lista em coluna fere a primeira forma normal (seção 14, tópico 03); quando o dado já chega assim (arquivo, tela, sistema legado), quebrar na consulta é o caminho.

## Quebrar

| Forma | Observação |
|---|---|
| `REGEXP_SUBSTR` + `CONNECT BY LEVEL` sobre `DUAL` | A clássica, para **um** texto (parâmetro) |
| A mesma dentro de `CROSS JOIN LATERAL` `[12c+]` | Para uma coluna, linha a linha da tabela |
| `JSON_TABLE` `[12c+]` | Troca o separador por `","` e lê como array JSON; dá a posição com `FOR ORDINALITY`. Quebra se o valor tiver aspas ou barra invertida |
| Function `PIPELINED` (seção 09, tópico 11) | Lógica reaproveitável: `SELECT * FROM TABLE(split(:texto, ';'))` |
| `APEX_STRING.SPLIT` | Pronta, se o APEX estiver instalado no banco |

### Três armadilhas

1. **Elemento vazio**: o padrão `'[^;]+'` pula o vazio de `'2;3;;7'` e desloca as posições (o `7` vira o terceiro). Para preservar posições: `REGEXP_SUBSTR(s, '([^;]*)(;|$)', 1, LEVEL, NULL, 1)`, com `LEVEL <= REGEXP_COUNT(s, ';') + 1`.
2. **`CONNECT BY` sempre devolve a primeira linha**: a condição só limita os filhos, então texto NULL ainda gera uma linha (com NULL). Filtrar o NULL antes.
3. **`CONNECT BY LEVEL` sobre tabela com várias linhas**, sem `LATERAL` nem `PRIOR`, combina as linhas entre si e multiplica o resultado. Por isso a geração fica sobre `DUAL`, dentro do `LATERAL`.

### Lista de parâmetro no `IN`

Uma tela que manda `'SP,TO'` não deve virar `'... WHERE uf IN (' || :lista || ')'` em SQL dinâmico (injeção de SQL, seção 09, tópico 09, e um cursor novo para cada lista, seção 11, tópico 07). Quebrar a lista numa subconsulta mantém a consulta estática, com uma bind.

## Juntar

| Forma | Observação |
|---|---|
| `LISTAGG(col, ', ') WITHIN GROUP (ORDER BY ...)` | Padrão. Também analítica: `... OVER (PARTITION BY ...)` |
| `LISTAGG(DISTINCT ...)` `[19c]` | Sem repetição. Antes: `DISTINCT` numa subconsulta |
| `ON OVERFLOW TRUNCATE '...' WITH COUNT` `[12.2+]` | Em vez de **ORA-01489** quando passa de 4000 bytes (ou 32767 com `MAX_STRING_SIZE = EXTENDED`), corta e informa quantos ficaram de fora |
| `XMLAGG(...).GETCLOBVAL()` | Resultado em CLOB, sem limite de 4000. Caracteres especiais de XML (`<`, `>`, e o e comercial) saem escapados como entidades |
| `JSON_ARRAYAGG(... RETURNING CLOB)` `[12.2+]` | Quando o destino aceita JSON |

## Documentação oficial

- [SQL Language Reference — LISTAGG](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/LISTAGG.html)
- [SQL Language Reference — REGEXP_SUBSTR](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/REGEXP_SUBSTR.html)
- [SQL Language Reference — JSON_TABLE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/JSON_TABLE.html)
