# Materialized views

## O que é

Uma materialized view (MV) é uma consulta cujo **resultado fica gravado**, como uma tabela. Consultá-la não executa a consulta de origem: lê o resultado já calculado. Em troca, ela fica desatualizada quando os dados de origem mudam, até ser **atualizada** (refresh).

Usos: resumos e agregações pesadas consultadas com frequência (painéis, relatórios), cópias de dados de outro banco (via database link), pré-junção de tabelas grandes.

## Criação

```sql
CREATE MATERIALIZED VIEW mv_vendas_mes
  BUILD IMMEDIATE              -- calcula na criação (DEFERRED: só no primeiro refresh)
  REFRESH COMPLETE ON DEMAND   -- como e quando atualizar
AS
SELECT ...;
```

## Como atualizar

| Método | O que faz | Requisito |
|---|---|---|
| `COMPLETE` | Apaga e recalcula tudo | Nenhum |
| `FAST` | Aplica só as mudanças desde o último refresh | **MV log** em cada tabela de origem e consulta dentro das regras de refresh rápido |
| `FORCE` (padrão) | `FAST` se possível, senão `COMPLETE` | |

## Quando atualizar

| Momento | Como |
|---|---|
| `ON DEMAND` (padrão) | Quando alguém chamar `DBMS_MVIEW.REFRESH('mv', 'C')` (`'F'` rápido, `'?'` force) |
| `ON COMMIT` | Automaticamente a cada commit nas tabelas de origem (exige `FAST`); torna os commits mais lentos |
| Agendado | `START WITH ... NEXT ...` na própria MV, ou um job do `DBMS_SCHEDULER` chamando o refresh (seção 13) |

## MV log

```sql
CREATE MATERIALIZED VIEW LOG ON itens_pedido
  WITH ROWID, SEQUENCE (id_pedido, quantidade, preco_unitario, pct_desconto)
  INCLUDING NEW VALUES;
```

Tabela auxiliar que registra cada alteração na tabela de origem para o refresh rápido. Toda DML na tabela passa a gravar também no log: tem custo.

Para MV com agregação ser atualizável por `FAST`, a consulta precisa ter `COUNT(*)` e, para cada `SUM(x)`, também `COUNT(x)`. `DBMS_MVIEW.EXPLAIN_MVIEW` diz o que falta para uma MV aceitar refresh rápido.

## Situação no dicionário

`USER_MVIEWS` mostra `LAST_REFRESH_DATE`, `STALENESS` (`FRESH`, `STALE`, `NEEDS_COMPILE`) e o método de refresh.

## Query rewrite

Com `ENABLE QUERY REWRITE` na MV, o otimizador pode reescrever uma consulta feita **sobre as tabelas de origem** para ler da MV, sem a aplicação saber. Útil em data warehouse; exige que a MV esteja atualizada (ou o parâmetro `QUERY_REWRITE_INTEGRITY` permita dados desatualizados).

## Documentação oficial

- [SQL Language Reference — CREATE MATERIALIZED VIEW](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/CREATE-MATERIALIZED-VIEW.html)
- [Data Warehousing Guide — Basic Materialized Views](https://docs.oracle.com/en/database/oracle/oracle-database/19/dwhsg/basic-materialized-views.html)
