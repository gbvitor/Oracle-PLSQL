# Formatação: LINESIZE, PAGESIZE, COLUMN, BREAK, COMPUTE

O SQL*Plus formata a saída como relatório de texto. Os comandos valem para a sessão (ou até serem desfeitos) e não mudam o dado, só a exibição.

## Página e linha

| SET | Efeito | Valor útil |
|---|---|---|
| `LINESIZE n` | Largura da linha | 200 a 32767 para consulta larga |
| `PAGESIZE n` | Linhas por página; o cabeçalho se repete a cada página | 50000 para não repetir; 0 para nenhum cabeçalho (tópico 06) |
| `FEEDBACK ON/OFF/n` | Mensagem "n linhas selecionadas" | OFF em relatório |
| `HEADING ON/OFF` | Linha com os nomes das colunas | |
| `NULL texto` | Como exibir NULL | `SET NULL '(nulo)'` deixa visível o que é NULL e o que é texto vazio |
| `NUMWIDTH n` / `NUMFORMAT fmt` | Largura e formato padrão de números | |
| `TIMING ON` | Tempo de cada comando | |
| `TAB OFF` | Espaços em vez de tabulação na saída | Para copiar a saída sem desalinhar |
| `TRIMOUT ON` / `TRIMSPOOL ON` | Tira espaços do fim das linhas na tela / no arquivo | |
| `WRAP OFF` | Corta a linha em vez de quebrá-la | |

## COLUMN

```sql
COLUMN nome           FORMAT A30 HEADING 'Cliente'
COLUMN limite_credito FORMAT 999G999G990D00 HEADING 'Limite|de crédito'
COLUMN observacao     FORMAT A40 WORD_WRAPPED
COLUMN documento      NOPRINT
COLUMN nome           CLEAR
CLEAR COLUMNS
```

| Opção | Efeito |
|---|---|
| `FORMAT An` | Texto com largura n (quebra o resto em linhas; `TRUNCATED` corta) |
| `FORMAT 999G990D00` | Número com separador de milhar (`G`) e decimal (`D`) do NLS; `9` = dígito opcional, `0` = obrigatório |
| `FORMAT 999,990.00` | Separadores fixos, independentes do NLS |
| `HEADING 'a\|b'` | Título, com `\|` quebrando em duas linhas |
| `JUSTIFY LEFT/CENTER/RIGHT` | Alinhamento do título |
| `NOPRINT` | Não exibe (útil com `NEW_VALUE`, tópico 03) |
| `NEW_VALUE var` | Guarda o valor numa variável de substituição |

Número maior que o formato aparece como `####`. O formato de coluna afeta só a exibição; para o arquivo de saída ter o mesmo formato num CSV, formate no SQL (`TO_CHAR`).

## BREAK e COMPUTE: subtotal sem GROUP BY

```sql
BREAK ON cliente SKIP 1 ON REPORT
COMPUTE SUM LABEL 'Subtotal' OF valor ON cliente
COMPUTE SUM LABEL 'Total'    OF valor ON REPORT
```

- `BREAK ON coluna` suprime o valor repetido e marca a quebra; a consulta precisa estar **ordenada** por essa coluna.
- `SKIP n` / `SKIP PAGE` dá espaço entre os grupos.
- `COMPUTE SUM|AVG|COUNT|MIN|MAX OF coluna ON quebra` calcula na quebra; `ON REPORT` no fim.
- `CLEAR BREAKS` e `CLEAR COMPUTES` desfazem.

Para subtotais que precisam ir para um sistema ou arquivo, `GROUP BY ROLLUP` (seção 02) é o equivalente em SQL; BREAK e COMPUTE servem para relatório de tela ou texto.

## Título de página

`TTITLE CENTER 'Pedidos por cliente' SKIP 2` e `BTITLE`, com `SQL.PNO` para número de página. Pouco usado hoje fora de relatórios de texto agendados.

## Saída em outros formatos

| SET | Saída |
|---|---|
| `SET MARKUP CSV ON [DELIMITER ;] [QUOTE ON]` `[12.2+]` | CSV (tópico 06) |
| `SET MARKUP HTML ON` | Tabela HTML |
| SQLcl: `SET SQLFORMAT ansiconsole` | Colunas ajustadas sozinhas à largura dos dados (tópico 10) |

## Documentação oficial

- [SQL*Plus User's Guide — Formatting SQL*Plus Reports](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/formatting-SQL-Plus-reports.html)
- [SQL*Plus User's Guide — COLUMN, BREAK, COMPUTE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/SQL-Plus-command-reference.html)
