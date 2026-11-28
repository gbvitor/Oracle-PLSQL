# EXPLAIN PLAN e DBMS_XPLAN.DISPLAY

`EXPLAIN PLAN` pede ao otimizador o plano que ele **escolheria** para uma instrução, sem executá-la. O resultado vai para a tabela `PLAN_TABLE` e é lido com `DBMS_XPLAN.DISPLAY`.

```sql
EXPLAIN PLAN FOR
SELECT * FROM pedidos WHERE id_cliente = 42;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

- `SET STATEMENT_ID = 'x'` identifica o plano quando vários são gravados: `DBMS_XPLAN.DISPLAY(statement_id => 'x')`.
- `PLAN_TABLE` já existe como tabela temporária global pública (sinônimo para `SYS.PLAN_TABLE$`) desde o 10g; não precisa criar.
- No SQL Developer, F10 faz o mesmo; no SQL*Plus, `SET AUTOTRACE TRACEONLY EXPLAIN` (tópico 10).

## Formatos

| Formato | Mostra |
|---|---|
| `BASIC` | Só as operações e os objetos |
| `TYPICAL` (padrão) | + linhas estimadas (`Rows`), bytes, custo, tempo estimado e predicados |
| `ALL` | + projeção de colunas e aliases das tabelas (útil para hints, tópico 08) |
| Modificadores | `+PREDICATE`, `-COST`, `+ALIAS`, `+OUTLINE` (o conjunto de hints que reproduz o plano), `+NOTE` |

Exemplo: `DBMS_XPLAN.DISPLAY(format => 'TYPICAL +ALIAS -BYTES')`.

## A seção de predicados

Abaixo do plano, cada operação numerada pode ter:

- **`access`**: condição usada para **chegar** às linhas (ler só a faixa certa do índice). É o que torna o acesso eficiente.
- **`filter`**: condição aplicada **depois** de ler, descartando linhas. Um filtro numa operação que leu milhões de linhas é sinal de trabalho jogado fora.

A mesma condição pode aparecer como `access` num plano e como `filter` em outro; é a primeira coisa a olhar quando um índice "não está sendo usado direito".

A seção `Note` avisa coisas importantes: `dynamic statistics used` (tabela sem estatísticas), `this is an adaptive plan`, `SQL plan baseline used`.

## O limite do EXPLAIN PLAN

É uma **previsão**, e pode diferir do plano que a execução real usa:

- Bind variables: o EXPLAIN PLAN não olha o valor (não faz *bind peeking*) e trata o bind como `VARCHAR2`. Com `WHERE id = :x` numa coluna NUMBER, o plano previsto pode mostrar uma conversão que a execução real não faz.
- Planos adaptativos `[12c+]` decidem o método de junção durante a execução.
- O ambiente da sessão (parâmetros, estatísticas novas) pode ser outro na hora em que a aplicação executa.

Para o plano que **de fato** rodou, com as linhas reais de cada etapa: `DBMS_XPLAN.DISPLAY_CURSOR` (tópico 03).

## Documentação oficial

- [SQL Tuning Guide — Generating and Displaying Execution Plans](https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/generating-and-displaying-execution-plans.html)
- [PL/SQL Packages and Types Reference — DBMS_XPLAN](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_XPLAN.html)
