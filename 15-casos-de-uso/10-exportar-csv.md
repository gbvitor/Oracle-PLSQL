# Exportação para CSV

## Cenário

Uma consulta precisa virar arquivo CSV: para abrir no Excel, para outro sistema importar, para um envio periódico. As perguntas que decidem a forma: **onde o arquivo deve ficar** (na máquina de quem roda ou no servidor do banco) e **quem vai ler** (Excel em português ou um sistema).

## As formas

| Forma | Arquivo fica em | Precisa de | Quando usar |
|---|---|---|---|
| SQL*Plus `SET MARKUP CSV ON` `[12.2+]` (seção 12, tópico 06) | Máquina do cliente | Nada além do SQL*Plus | Extração manual ou script agendado na máquina que tem o cliente |
| SQLcl `SET SQLFORMAT CSV` (seção 12, tópico 10) | Máquina do cliente | SQLcl | Idem, com mais formatos (JSON, INSERT, XML) |
| Function PL/SQL que devolve CLOB | Onde o CLOB for parar | `CREATE PROCEDURE` | Mesmo layout por qualquer caminho: SPOOL, aplicação, e-mail, UTL_FILE |
| `UTL_FILE` | **Servidor do banco**, num `DIRECTORY` | `CREATE DIRECTORY` (DBA) e `READ, WRITE` no diretório | Job agendado dentro do banco (DBMS_SCHEDULER) que deixa o arquivo para outro processo buscar |

O erro mais comum com `UTL_FILE` é esperar o arquivo na própria máquina: ele é gravado pelo processo do banco, no sistema de arquivos do servidor.

## Regras de um CSV correto (RFC 4180)

- Campo que contém o separador, aspas ou quebra de linha vai **entre aspas**.
- Aspas dentro do campo são **duplicadas**: `Diz "olá"` vira `"Diz ""olá"""`.
- Concatenar colunas com `';'` sem esse tratamento gera arquivo que abre com colunas deslocadas na primeira vírgula ou ponto e vírgula de um texto.

## Número, data e o Excel

| Ponto | Detalhe |
|---|---|
| Separador | Excel em português espera `;`, porque a vírgula é o separador decimal. Sistemas costumam esperar `,` e ponto decimal. |
| Decimal | Na conversão implícita, o número segue `NLS_NUMERIC_CHARACTERS` e perde os zeros à direita (`50000.00` vira `50000`). Para casas fixas: `TO_CHAR(valor, 'FM9999999990D00')`. |
| Data | Na conversão implícita, segue `NLS_DATE_FORMAT`. Para não depender da sessão: `TO_CHAR(data, 'DD/MM/YYYY')` ou ISO `YYYY-MM-DD` para sistemas. |
| Código com zero à esquerda | O Excel transforma `00123` em `123`. Não há conserto pelo CSV; importar a coluna como texto. |
| Codificação | O arquivo sai na codificação do cliente (`NLS_LANG`, no SPOOL) ou do banco (UTL_FILE). Para o Excel reconhecer UTF-8 com acentos, em geral é preciso o BOM no início do arquivo, ou gerar em Windows-1252. |

## A function genérica

`tmp_fn_csv` recebe o texto de uma consulta e devolve o CSV. Usa `DBMS_SQL` porque o número e os nomes das colunas só são conhecidos em execução (seção 09, tópico 09): `DESCRIBE_COLUMNS2` dá os nomes para o cabeçalho, e cada coluna é definida como `VARCHAR2`, o que converte número e data pelas regras NLS da sessão.

Dois cuidados que a function trata:

- **`DBMS_SQL.PARSE` executa DDL na hora**: passar `DROP TABLE x` executaria o `DROP`. A function só aceita texto que começa com `SELECT` ou `WITH`. Isso reduz o risco, não elimina; o texto da consulta não deve vir de entrada livre de usuário.
- **`AUTHID CURRENT_USER`**: a consulta roda com os privilégios de quem chama, não do dono da function (seção 09, tópico 14).

Limitações: colunas LOB, LONG e RAW não são tratadas (converta na consulta); cada valor até 4000 bytes.

## Documentação oficial

- [PL/SQL Packages and Types Reference — DBMS_SQL](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_SQL.html)
- [PL/SQL Packages and Types Reference — UTL_FILE](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/UTL_FILE.html)
- [RFC 4180 — Common Format and MIME Type for CSV Files](https://www.rfc-editor.org/rfc/rfc4180)
