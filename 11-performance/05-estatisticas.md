# Estatísticas: DBMS_STATS, histogramas e estatísticas desatualizadas

O otimizador decide com base em estatísticas guardadas no dicionário, não nos dados. Estatística errada é a causa mais comum de plano ruim.

## O que é coletado

| Nível | Estatísticas | Onde ver |
|---|---|---|
| Tabela | Linhas, blocos, tamanho médio de linha | `USER_TAB_STATISTICS`, `USER_TABLES` |
| Coluna | Valores distintos (`NUM_DISTINCT`), nulos, mínimo e máximo, **histograma** | `USER_TAB_COL_STATISTICS`, `USER_TAB_HISTOGRAMS` |
| Índice | Altura, folhas, chaves distintas, clustering factor | `USER_IND_STATISTICS`, `USER_INDEXES` |
| Sistema | Velocidade de leitura e CPU | `DBMS_STATS.GATHER_SYSTEM_STATS` (raramente necessário) |

## Coletar

```sql
EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'PEDIDOS')
EXEC DBMS_STATS.GATHER_SCHEMA_STATS(USER)
```

- O padrão (`estimate_percent => AUTO_SAMPLE_SIZE`, `method_opt => 'FOR ALL COLUMNS SIZE AUTO'`) é a escolha certa quase sempre. Desde o 11g, a amostra automática é rápida e tão precisa quanto ler tudo.
- `cascade` (padrão automático) coleta também os índices; criar índice já coleta as estatísticas dele.
- O **job automático** (*auto optimizer stats collection*) roda na janela de manutenção, normalmente à noite, e coleta o que está ausente ou desatualizado.
- `[12c+]` Carga em tabela vazia por `CREATE TABLE AS SELECT` ou `INSERT /*+ APPEND */` coleta estatísticas de tabela na própria carga (*online statistics gathering*).

## Histogramas

Sem histograma, o otimizador supõe que os valores de uma coluna são **igualmente frequentes**: com 3 status distintos em 200 mil linhas, estima 66.667 linhas para qualquer status. Se 98,9% são `ENTREGUE`, a estimativa erra para todos os valores, e o plano também.

Histograma descreve a distribuição. Tipos `[12c+]`:

| Tipo | Quando |
|---|---|
| `FREQUENCY` | Poucos valores distintos (até 254 por padrão; 2048 no máximo): conta exata por valor |
| `TOP-FREQUENCY` | Muitos valores, mas poucos concentram quase todas as linhas |
| `HYBRID` | Muitos valores distintos, distribuição irregular |
| `HEIGHT BALANCED` | Formato antigo (até 11g) |

Com `SIZE AUTO`, o Oracle cria histograma só em colunas que têm distribuição torta **e já foram usadas em filtros** (registro de uso de coluna). Por isso uma coluna nova pode ficar sem histograma até a segunda coleta depois de começar a aparecer em `WHERE`. Para forçar: `method_opt => 'FOR COLUMNS status SIZE 254'`.

Histograma e bind variable se influenciam: o tópico 07 trata disso.

## Estatísticas desatualizadas

`USER_TAB_STATISTICS.STALE_STATS = 'YES'` quando mais de 10% das linhas mudaram desde a última coleta (o limite é configurável com `DBMS_STATS.SET_TABLE_PREFS(..., 'STALE_PERCENT', ...)`). O monitoramento de DML grava as contagens em `USER_TAB_MODIFICATIONS` de tempos em tempos; `DBMS_STATS.FLUSH_DATABASE_MONITORING_INFO` força a gravação.

Dois casos clássicos:

- **Carga grande durante o dia**, antes do job noturno: o otimizador ainda acha que a tabela é pequena.
- **Valor fora da faixa conhecida**: datas posteriores ao máximo registrado na última coleta. O otimizador estima quase zero linhas para "pedidos de hoje" e escolhe nested loops, quando há milhares. Em tabelas com carga diária, é a origem de muitos "ficou lento depois das 10h".

A solução é coletar depois da carga (na própria rotina de carga) e, para tabelas que mudam muito, ajustar as preferências de coleta.

## Outras ferramentas

| Recurso | Para |
|---|---|
| `DBMS_STATS.LOCK_TABLE_STATS` | Congelar estatísticas boas (tabela de staging que é esvaziada e recarregada) |
| `DBMS_STATS.RESTORE_TABLE_STATS` + `USER_TAB_STATS_HISTORY` | Voltar às estatísticas de antes de uma coleta que piorou os planos |
| `DBMS_STATS.CREATE_EXTENDED_STATS` | **Column group**: colunas correlacionadas (`uf` e `cidade`) estimadas juntas, em vez de multiplicar seletividades |
| `DBMS_STATS.SET_TABLE_PREFS` | Preferências por tabela (amostra, histogramas, STALE_PERCENT) |
| Estatísticas dinâmicas (`OPTIMIZER_DYNAMIC_SAMPLING`) | Amostra feita no parse para tabelas sem estatísticas |

## Documentação oficial

- [SQL Tuning Guide — Optimizer Statistics Concepts](https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/optimizer-statistics-concepts.html)
- [SQL Tuning Guide — Histograms](https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/histograms.html)
- [PL/SQL Packages and Types Reference — DBMS_STATS](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_STATS.html)
