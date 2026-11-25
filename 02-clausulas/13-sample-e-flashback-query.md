# SAMPLE e Flashback Query

Duas extensões do `FROM`: uma lê só uma parte da tabela, a outra lê a tabela como ela estava no passado.

## SAMPLE

```sql
-- cerca de 10% das linhas
SELECT * FROM pedidos SAMPLE (10);

-- mesma amostra a cada execução
SELECT * FROM pedidos SAMPLE (10) SEED (42);

-- cerca de 10% dos blocos
SELECT * FROM pedidos SAMPLE BLOCK (10);
```

- O percentual é **aproximado**: cada linha tem 10% de chance de entrar. Em 24 linhas, o resultado pode ter 0, 2, 5...
- `SEED (n)` fixa o gerador e torna a amostra reproduzível enquanto os dados não mudarem.
- `SAMPLE BLOCK` sorteia blocos inteiros: muito mais rápido em tabela grande, menos aleatório (linhas do mesmo bloco vêm juntas).

Uso: estimar distribuição ou testar uma consulta pesada em tabela de milhões de linhas antes de rodar no todo. Para "N linhas aleatórias exatas", `ORDER BY DBMS_RANDOM.VALUE FETCH FIRST N ROWS ONLY` (que lê a tabela inteira).

## Flashback Query

```sql
SELECT * FROM produtos AS OF TIMESTAMP SYSTIMESTAMP - INTERVAL '10' MINUTE;
SELECT * FROM produtos AS OF SCN 12345678;
```

Lê os dados como estavam num momento anterior, usando as informações de **undo** que o Oracle já guarda para consistência de leitura. Não precisa de backup nem de configuração especial para janelas curtas.

Usos:

- **Ver o valor antes de um erro.** "Quanto era o preço antes daquele UPDATE?"
- **Recuperar dados** com um `UPDATE ... SET col = (SELECT col FROM tabela AS OF ...)` ou `INSERT INTO tabela SELECT * FROM tabela AS OF ... WHERE ...`.
- **Comparar** o estado atual com o de uma hora atrás (`MINUS` entre os dois).

## Limites

- **Janela do undo.** O passado disponível depende de `UNDO_RETENTION` e do volume de alterações. Pedir um momento além do que o undo guarda dá ORA-01555 (snapshot muito antigo) ou ORA-08180.
- **DDL corta a história.** Depois de um `ALTER TABLE` que muda a estrutura, ou de um `TRUNCATE`, não dá para consultar antes dele (ORA-01466).
- **Precisão do TIMESTAMP.** O mapeamento entre horário e SCN tem resolução de alguns segundos. Para precisão, use SCN.
- **Privilégio.** Na própria tabela não precisa de nada; em tabela de outro schema, `FLASHBACK` no objeto ou `FLASHBACK ANY TABLE`.

Para ver **todas as versões** de uma linha num intervalo (`VERSIONS BETWEEN`) e para restaurar tabelas inteiras (`FLASHBACK TABLE`), ver a seção 13.

## Documentação oficial

- [SQL Language Reference — SELECT (sample_clause, flashback_query_clause)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SELECT.html)
- [Development Guide — Using Oracle Flashback Technology](https://docs.oracle.com/en/database/oracle/oracle-database/19/adfns/flashback.html)
