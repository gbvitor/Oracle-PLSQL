# Oracle SQL e PL/SQL — Referência

Repositório de estudo e consulta sobre Oracle Database: SQL, PL/SQL, SQL*Plus/SQLcl, dicionário de dados, performance e administração básica, com comparações com outros SGBDs. Cada tópico traz explicação didática, scripts executáveis, casos de uso e armadilhas comuns.

Todos os exemplos rodam sobre o mesmo schema fictício de vendas (`00-ambiente`), então qualquer script pode ser executado em sequência sem preparar dados à parte.

## Como usar

1. Suba um banco seguindo [00-ambiente](00-ambiente/README.md) (FreeSQL no navegador ou Oracle Free em container).
2. Crie o usuário de estudo e carregue o schema de exemplo.
3. Navegue pelas seções na ordem abaixo, ou vá direto ao tópico que precisar consultar.

## Mapa do conteúdo

| Seção | Conteúdo |
|---|---|
| [00 — Ambiente](00-ambiente/README.md) | Onde rodar, clientes, usuário de estudo, schema e dados de exemplo |
| [01 — Fundamentos](01-fundamentos/README.md) | Modelo relacional, tipos de dados, NULL, DUAL, pseudocolunas, ordem lógica de execução |
| [02 — Cláusulas](02-clausulas/README.md) | SELECT, FROM, WHERE, GROUP BY, HAVING, ORDER BY, FETCH, WITH, CONNECT BY, PIVOT, FOR UPDATE, RETURNING |
| [03 — Expressões e condições](03-expressoes-e-condicoes/README.md) | Operadores, precedência, CASE, DECODE, lógica de três valores, IN, BETWEEN, LIKE, EXISTS, datas e intervalos |
| [04 — Funções](04-funcoes/README.md) | Texto, número, data, conversão, NULL, agregação, analíticas, expressões regulares, JSON |
| [05 — Consultas](05-consultas/README.md) | Joins, subqueries, operadores de conjunto, último registro e top-N por grupo, duplicidades, gaps and islands, LATERAL/APPLY |
| [06 — DML e transações](06-dml-e-transacoes/README.md) | INSERT, UPDATE, DELETE, MERGE, COMMIT, ROLLBACK, SAVEPOINT, consistência de leitura, locks |
| [07 — DDL e objetos](07-ddl-e-objetos/README.md) | Tabelas, constraints, índices, views, materialized views, sequences, identity, synonyms, DBMS_METADATA |
| [08 — PL/SQL: fundamentos](08-plsql-fundamentos/README.md) | Blocos, variáveis, %TYPE/%ROWTYPE, SELECT INTO, IF/CASE, laços, cursores, exceções, propagação, records |
| [09 — PL/SQL: avançado](09-plsql-avancado/README.md) | Procedures, functions, packages, triggers, coleções, BULK COLLECT/FORALL, SQL dinâmico, pipelined |
| [10 — Dicionário de dados](10-dicionario-de-dados/README.md) | Visões USER_/ALL_/DBA_, V$, consultas de descoberta de estrutura |
| [11 — Performance](11-performance/README.md) | Plano de execução, DBMS_XPLAN, estatísticas, índices, bind variables, hints |
| [12 — SQL*Plus e SQLcl](12-sqlplus-sqlcl/README.md) | Comandos, formatação, spool, variáveis de substituição, scripts |
| [13 — Administração](13-administracao/README.md) | Usuários, privilégios, roles, sessões e locks, DBMS_SCHEDULER, flashback, Data Pump |
| [14 — Outros SGBDs](14-sgbds/README.md) | Conceitos gerais e equivalência de sintaxe com PostgreSQL, SQL Server e MySQL |
| [15 — Casos de uso](15-casos-de-uso/README.md) | Último por grupo, acumulado mensal, ranking, curva ABC, anti-join, auditoria, carga com MERGE, calendário, CPF/CNPJ, CSV, lote, comparar tabelas, texto delimitado |
| [16 — Mini-projetos](16-mini-projetos/README.md) | Estoque, biblioteca, faturamento, log e auditoria, API com utPLSQL: modelagem, packages e testes de aceite |
| [Referências](referencias/README.md) | Folhas de SQL e PL/SQL, máscaras de formato, erros ORA- comuns, glossário, documentação oficial |

## Versão do Oracle

O conteúdo é escrito para funcionar no **Oracle 19c**, a versão mais usada em produção hoje. Recursos que só existem em versões mais novas são marcados no texto e no comentário do script:

- `[21c+]` — disponível a partir do 21c
- `[23ai+]` — disponível a partir do 23ai (inclui o 26ai, que é a release 23.26)

Os ambientes gratuitos atuais (FreeSQL e Oracle AI Database Free) rodam 26ai, então tudo que está marcado também roda neles.

## Convenções

Estrutura de cada tópico, nomenclatura de arquivos e padrão dos scripts: [CONVENCOES.md](CONVENCOES.md).
