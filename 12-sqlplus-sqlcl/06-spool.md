# SPOOL e geração de arquivos (CSV, relatório texto)

`SPOOL arquivo` copia para um arquivo tudo o que o SQL*Plus exibe, até `SPOOL OFF`. O arquivo é gravado **na máquina onde o SQL*Plus está rodando**, não no servidor do banco (para gravar no servidor, `UTL_FILE`, seção 09, tópico 16).

```sql
SPOOL pedidos.csv
SELECT ...;
SPOOL OFF
```

| Forma | Efeito |
|---|---|
| `SPOOL arquivo` | Cria ou substitui (extensão `.lst` se omitida) |
| `SPOOL arquivo APPEND` | Acrescenta ao fim |
| `SPOOL arquivo REPLACE` | Substitui (o padrão, explícito) |
| `SPOOL` | Mostra se está gravando e em qual arquivo |
| `SPOOL OFF` | Fecha o arquivo |

## CSV: o jeito moderno `[12.2+]`

```sql
SET MARKUP CSV ON DELIMITER ; QUOTE ON
SET FEEDBACK OFF
SPOOL pedidos.csv
SELECT ...;
SPOOL OFF
SET MARKUP CSV OFF
```

Cabeçalho com os nomes das colunas, textos entre aspas, números sem formatação, sem espaços de alinhamento. O SQLcl tem o equivalente com `SET SQLFORMAT csv` (tópico 10).

## CSV: o jeito clássico (qualquer versão)

```sql
SET PAGESIZE 0
SET FEEDBACK OFF
SET HEADING OFF
SET LINESIZE 32767
SET TRIMSPOOL ON
SET TERMOUT OFF
SET VERIFY OFF
SET ECHO OFF
SPOOL pedidos.csv
SELECT 'id_pedido;status;valor' FROM dual;
SELECT id_pedido || ';' || status || ';' || TO_CHAR(valor, 'FM999999990D00') FROM ...;
SPOOL OFF
SET TERMOUT ON
```

| SET | Por quê |
|---|---|
| `PAGESIZE 0` | Sem cabeçalhos, sem quebras de página |
| `FEEDBACK OFF` | Sem "24 linhas selecionadas" no fim do arquivo |
| `LINESIZE 32767` + `TRIMSPOOL ON` | Linha longa sem quebra, sem espaços de preenchimento no fim |
| `TERMOUT OFF` | Não mostra na tela (mais rápido). **Só funciona dentro de script** (`@arquivo`), não em comando digitado |
| `ECHO OFF` | Não grava os próprios comandos no arquivo |

Separador `;` e decimal com vírgula abrem direto no Excel em português; `,` e ponto, no Excel em inglês. Escolha pelo destino do arquivo.

## Nome de arquivo com data

```sql
COLUMN hoje NEW_VALUE v_hoje NOPRINT
SELECT TO_CHAR(SYSDATE, 'YYYYMMDD') AS hoje FROM dual;
SPOOL pedidos_&v_hoje..csv
```

O primeiro ponto encerra o nome da variável; o segundo fica no nome do arquivo (tópico 03).

## Acentos no arquivo

A codificação do arquivo segue o `NLS_LANG` do **cliente**, não o banco. No Windows, sem `NLS_LANG` configurado, acentos saem trocados. Defina antes de abrir o SQL*Plus:

```text
Windows (Excel)  set NLS_LANG=BRAZILIAN PORTUGUESE_BRAZIL.WE8MSWIN1252
Linux (UTF-8)    export NLS_LANG=BRAZILIAN PORTUGUESE_BRAZIL.AL32UTF8
```

A parte de idioma e território também muda as mensagens, o formato de data e os separadores numéricos (`G` e `D`).

## Documentação oficial

- [SQL*Plus User's Guide — SPOOL](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/SPOOL.html)
- [SQL*Plus User's Guide — SET MARKUP](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/SET-system-variable-summary.html)
- [Globalization Support Guide — Setting NLS_LANG](https://docs.oracle.com/en/database/oracle/oracle-database/19/nlspg/setting-up-globalization-support-environment.html)
