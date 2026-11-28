# Comparar duas tabelas e listar as diferenças

## Cenário

Duas versões da mesma tabela precisam ser comparadas: produção e homologação, antes e depois de uma carga, a tabela e o backup de ontem, o banco local e o remoto (por database link). A pergunta é sempre a mesma: **o que só existe de um lado, o que só existe do outro e o que mudou**.

## As técnicas

| Técnica | Responde | Observação |
|---|---|---|
| `A MINUS B` e `B MINUS A` | Linhas de um lado sem igual do outro | Simples; trata NULL como igual a NULL; linha alterada aparece nos dois resultados; lê cada tabela duas vezes |
| `UNION ALL` + `GROUP BY` + `HAVING` | As mesmas linhas, numa consulta só | Uma leitura de cada tabela; também trata NULL como igual; mostra de que lado veio cada versão |
| `FULL OUTER JOIN` pela chave | Só em A, só em B, alterado **e quais colunas** | O relatório mais útil; exige chave e comparação que trate NULL |
| Impressão digital (contagem e soma de hash) | Se as tabelas são iguais, sem listar | Rápida para tabelas grandes ou remotas; colisão de hash é possível, então "igual" é indício forte, não prova |

`DBMS_COMPARISON` é o pacote nativo para comparar (e sincronizar) tabelas entre bancos; exige configuração (comparação registrada, índice na chave) e compensa em rotina repetida, não em conferência pontual.

## A armadilha do NULL

A comparação ingênua `WHERE a.coluna <> b.coluna` não encontra a troca de NULL por valor nem de valor por NULL, porque `NULL <> 'x'` é desconhecido, não verdadeiro. No exemplo, ela acha 2 das 5 alterações. As formas que tratam NULL:

```sql
DECODE(a.col, b.col, 0, 1) = 1                       -- DECODE trata NULL = NULL
(a.col <> b.col OR (a.col IS NULL AND b.col IS NOT NULL) OR (a.col IS NOT NULL AND b.col IS NULL))
a.col IS DISTINCT FROM b.col                         -- padrão SQL; não existe no Oracle 19c
```

`MINUS`, `UNION`, `GROUP BY` e `DISTINCT` já consideram dois NULLs iguais.

## Contagem igual não é tabela igual

No exemplo, as duas versões têm 12 linhas, com uma excluída e uma incluída. Conferir carga só por `COUNT(*)` não pega isso.

## Resultados de referência

Mudanças aplicadas na cópia B: cliente 1 com limite 55.000; cliente 3 ganhou e-mail; cliente 5 perdeu o e-mail; cliente 7 ganhou limite 1.000; cliente 9 mudou de cidade; cliente 4 "atualizado" com os mesmos valores; cliente 12 excluído; cliente 13 incluído.

| Técnica | Resultado |
|---|---|
| `A MINUS B` | 1, 3, 5, 7, 9, 12 |
| `B MINUS A` | 1, 3, 5, 7, 9, 13 |
| `<>` ingênuo | 1, 9 |
| `FULL OUTER JOIN` | 5 alterados, 12 só em A, 13 só em B; o cliente 4 não aparece |

## Documentação oficial

- [SQL Language Reference — The UNION, INTERSECT, MINUS Operators](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/The-UNION-ALL-INTERSECT-MINUS-Operators.html)
- [PL/SQL Packages and Types Reference — DBMS_COMPARISON](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_COMPARISON.html)
