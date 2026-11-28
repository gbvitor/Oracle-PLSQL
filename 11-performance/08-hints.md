# Hints: quando fazem sentido e os mais comuns

Hint é uma instrução ao otimizador, escrita num comentário especial logo depois da palavra-chave: `SELECT /*+ FULL(p) */ ...`. Ele restringe as escolhas do otimizador; não é uma sugestão vaga, mas também não gera erro quando não pode ser cumprido.

## Regras de escrita

- Formato: `/*+ hint1 hint2 */`, **imediatamente depois** de `SELECT`, `INSERT`, `UPDATE`, `DELETE` ou `MERGE`. Comentário comum antes do hint pode fazê-lo ser ignorado.
- Hint que se refere a tabela usa o **alias** da consulta, se houver: em `FROM pedidos p`, `FULL(p)`; `FULL(pedidos)` é ignorado.
- Hint escrito errado, com alias errado, ou que não pode ser aplicado é **ignorado em silêncio**. `[19c+]` O formato `+HINT_REPORT` do `DISPLAY_CURSOR` lista os hints usados e os não usados, com o motivo.
- Dentro de subconsultas e views, os hints valem para o bloco onde estão; para alcançar outro bloco, `QB_NAME` e a notação `alias@bloco`.

## Os mais comuns

| Hint | Faz |
|---|---|
| `FULL(t)` | Leitura completa de `t` |
| `INDEX(t nome_indice)`, `NO_INDEX(t nome)` | Usar ou evitar um índice |
| `LEADING(t1 t2 ...)` | Ordem de junção |
| `USE_NL(t)`, `USE_HASH(t)`, `USE_MERGE(t)` | Método de junção com `t` como tabela interna |
| `FIRST_ROWS(n)` | Otimizar para devolver as primeiras `n` linhas rápido (telas paginadas) |
| `ALL_ROWS` | Otimizar para o tempo total (padrão) |
| `PARALLEL(t n)` | Execução paralela; opção da **Enterprise Edition** |
| `APPEND` | Carga direta em `INSERT ... SELECT` (seção 06, tópico 01) |
| `MATERIALIZE`, `INLINE` | Forçar ou evitar que um `WITH` vire tabela temporária |
| `NO_MERGE(v)`, `NO_UNNEST` | Manter view ou subconsulta como bloco separado |
| `CARDINALITY(t n)` | Informar o número de linhas (não documentado oficialmente, mas muito usado em table functions) |
| `GATHER_PLAN_STATISTICS` | Estatísticas de execução para `DISPLAY_CURSOR` (tópico 03) |
| `OPT_PARAM('parâmetro' valor)` | Mudar um parâmetro do otimizador só nesta instrução |

## Quando usar

**Faz sentido:**

- **Diagnóstico**: forçar o plano alternativo para comparar `Buffers` e tempo (`DISPLAY_CURSOR`). Se o plano forçado é muito melhor, a pergunta seguinte é *por que o otimizador não o escolheu*, quase sempre uma cardinalidade errada.
- **Hints de comportamento** que não escolhem plano: `APPEND`, `PARALLEL` em carga controlada, `GATHER_PLAN_STATISTICS`, `MATERIALIZE`.
- Casos em que o otimizador não tem como saber: table function, tabela temporária com conteúdo muito variável (`CARDINALITY`, `DYNAMIC_SAMPLING`).

**Evite:**

- Hint como correção permanente de estatística errada. O dado muda, o hint fica, e daqui a um ano ele força o plano errado.
- Hints de acesso espalhados no código da aplicação: ninguém lembra por que estão ali.

**Alternativas que não mexem no código:**

| Recurso | Para |
|---|---|
| Corrigir estatísticas, histograma, column group (tópico 05) | A causa, em vez do sintoma |
| **SQL Plan Baseline** (`DBMS_SPM`) | Fixar um plano aceito para uma instrução, sem alterar o texto. Incluído na Enterprise Edition |
| **SQL Patch** (`DBMS_SQLDIAG.CREATE_SQL_PATCH`) | Injetar um hint numa instrução de aplicação que você não pode alterar |
| SQL Profile (`DBMS_SQLTUNE`) | Correções de estimativa sugeridas pelo SQL Tuning Advisor; exige **Tuning Pack** |

## Documentação oficial

- [SQL Language Reference — Comments: Hints](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Comments.html)
- [SQL Tuning Guide — Influencing the Optimizer with Hints](https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/influencing-the-optimizer.html)
- [SQL Tuning Guide — Managing SQL Plan Baselines](https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/managing-sql-plan-baselines.html)
