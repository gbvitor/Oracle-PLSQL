# Dependências: quem usa esta tabela?

Este tópico é a parte de **consulta** do assunto. Como a dependência é registrada, o que invalida o quê e como recompilar está na seção 09, tópico 15.

## As visões

| Visão | Mostra |
|---|---|
| `USER_DEPENDENCIES` | Para cada objeto seu (`NAME`, `TYPE`), cada objeto de que ele depende (`REFERENCED_OWNER`, `REFERENCED_NAME`, `REFERENCED_TYPE`) |
| `ALL_DEPENDENCIES`, `DBA_DEPENDENCIES` | O mesmo entre schemas: é onde aparece o código de **outro** usuário que usa a sua tabela |
| `PUBLIC_DEPENDENCY` | A mesma relação por número de objeto (`OBJECT_ID`) |

As duas direções:

| Pergunta | Filtro |
|---|---|
| "Quem usa a tabela PEDIDOS?" (impacto de alterar) | `WHERE referenced_name = 'PEDIDOS'` |
| "Do que a procedure X depende?" (o que precisa existir para ela compilar) | `WHERE name = 'X'` |

Dependência indireta (a procedure usa uma view que usa a tabela) exige percorrer em árvore, com `CONNECT BY` ou WITH recursivo.

## O que a dependência não mostra

| Situação | Onde procurar |
|---|---|
| SQL dinâmico (`EXECUTE IMMEDIATE`, `DBMS_SQL`) | Texto em `USER_SOURCE` (tópico 05) |
| Código de outros schemas | `ALL_DEPENDENCIES` / `DBA_DEPENDENCIES` |
| Jobs (`DBMS_SCHEDULER`) com bloco PL/SQL | `USER_SCHEDULER_JOBS.JOB_ACTION` |
| Aplicação, relatórios, ETL, planilhas | Fora do banco: repositório de código, ferramentas de BI |
| Database links de outros bancos | No outro banco |

Uma análise de impacto honesta combina as três fontes do banco (dependências, texto do código, jobs) e deixa explícito o que ficou de fora.

## Documentação oficial

- [Database Reference — ALL_DEPENDENCIES](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/ALL_DEPENDENCIES.html)
- [Database Development Guide — Schema Object Dependency](https://docs.oracle.com/en/database/oracle/oracle-database/19/adfns/schema-object-dependency.html)
