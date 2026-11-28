# Parâmetros de inicialização e NLS

## Parâmetros

O comportamento da instância é controlado por centenas de parâmetros (`SGA_TARGET`, `PROCESSES`, `OPEN_CURSORS`, `UNDO_RETENTION`, `OPTIMIZER_MODE`...), guardados no **spfile** e lidos na inicialização.

| Onde ver | Mostra |
|---|---|
| `V$PARAMETER` | O valor em vigor **na sessão atual** |
| `V$SYSTEM_PARAMETER` | O valor em vigor na instância |
| `V$SPPARAMETER` | O que está no spfile (vale na próxima inicialização) |
| `SHOW PARAMETER texto` (SQL*Plus) | Busca por parte do nome |

Colunas úteis de `V$PARAMETER`: `ISDEFAULT` (nunca foi alterado), `ISSES_MODIFIABLE` (`ALTER SESSION` aceita), `ISSYS_MODIFIABLE` (`IMMEDIATE` = muda na hora; `DEFERRED` = vale para sessões novas; `FALSE` = só com reinício), `ISPDB_MODIFIABLE` (pode ter valor próprio por PDB).

```sql
ALTER SESSION SET optimizer_index_cost_adj = 50;
ALTER SYSTEM SET open_cursors = 500 SCOPE = BOTH;
ALTER SYSTEM SET processes = 600 SCOPE = SPFILE;
```

| `SCOPE` | Efeito |
|---|---|
| `MEMORY` | Só na instância em execução; perde-se no reinício |
| `SPFILE` | Só no spfile; vale no próximo reinício (obrigatório para parâmetros estáticos) |
| `BOTH` (padrão com spfile) | Os dois |

Parâmetros que começam com `_` (*hidden*) só devem ser alterados por orientação do suporte da Oracle.

## NLS: idioma, território e caracteres

As configurações NLS (*National Language Support*) decidem formato de data, separadores numéricos, idioma das mensagens e dos nomes de mês e dia, ordenação e comparação de texto. Valem em camadas, da mais geral para a mais específica:

| Camada | Visão | Definido por |
|---|---|---|
| Banco | `NLS_DATABASE_PARAMETERS` | Criação do banco (o **character set** não muda depois sem migração) |
| Instância | `NLS_INSTANCE_PARAMETERS` | Parâmetros de inicialização |
| Sessão | `NLS_SESSION_PARAMETERS` | Variável `NLS_LANG` e `NLS_*` do **cliente**, `ALTER SESSION`, login.sql |
| Função | Argumento opcional | `TO_CHAR(data, 'Month', 'NLS_DATE_LANGUAGE = PORTUGUESE')` |

A sessão vence a instância, e a função vence a sessão. Por isso o mesmo `SELECT TO_CHAR(SYSDATE)` dá resultados diferentes no SQL*Plus de uma máquina, no SQL Developer de outra e na aplicação: cada cliente define a sua sessão. **Código não deve depender do NLS da sessão**: informe sempre a máscara (`TO_DATE('27/11/2026', 'DD/MM/YYYY')`) e, quando o idioma importar, o argumento NLS da função.

## Character set e tamanho de coluna

| | |
|---|---|
| `NLS_CHARACTERSET` | Conjunto de caracteres de `VARCHAR2`, `CHAR`, `CLOB`. O recomendado é `AL32UTF8` (Unicode); bancos antigos usam `WE8MSWIN1252` ou `WE8ISO8859P1` |
| `NLS_NCHAR_CHARACTERSET` | De `NVARCHAR2`, `NCHAR`, `NCLOB` (normalmente `AL16UTF16`) |
| `NLS_LENGTH_SEMANTICS` | Se `VARCHAR2(10)` significa 10 **bytes** (padrão `BYTE`) ou 10 **caracteres** (`CHAR`) |

Em `AL32UTF8`, letras acentuadas ocupam 2 bytes. Uma coluna `VARCHAR2(4)` em semântica de bytes **não comporta** `'ação'` (4 caracteres, 5 bytes): ORA-12899. Declare com a unidade explícita (`VARCHAR2(100 CHAR)`) em colunas de texto livre, ou use `NLS_LENGTH_SEMANTICS = CHAR` ao criar o schema. `LENGTH` conta caracteres; `LENGTHB`, bytes.

## Ordenação e comparação

| Configuração | Efeito |
|---|---|
| `NLS_SORT = BINARY` (padrão) | Ordena pelo código do caractere: maiúsculas antes das minúsculas, acentuadas depois de tudo |
| `NLS_SORT = BRAZILIAN`, `XSPANISH`, `GENERIC_M` | Ordem do idioma |
| `NLS_SORT = BINARY_CI` / `BINARY_AI` | Ignora maiúsculas / maiúsculas e acentos |
| `NLS_COMP = LINGUISTIC` | Faz `=`, `LIKE` e `<` usarem o `NLS_SORT` (senão, só o `ORDER BY` usa) |

Comparação linguística não usa índice comum: exige índice com `NLSSORT(coluna, 'NLS_SORT=BINARY_AI')`. `[12.2+]` A cláusula `COLLATE` permite definir a regra por coluna (`nome VARCHAR2(100) COLLATE BINARY_AI`), sem depender da sessão; exige o parâmetro `MAX_STRING_SIZE = EXTENDED`. Sem ele, a regra vai na consulta com `NLSSORT` (script, passo 5).

## Documentação oficial

- [Database Reference — Initialization Parameters](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/initialization-parameters.html)
- [Database Administrator's Guide — Managing Initialization Parameters Using a Server Parameter File](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/creating-and-configuring-an-oracle-database.html)
- [Globalization Support Guide](https://docs.oracle.com/en/database/oracle/oracle-database/19/nlspg/index.html)
