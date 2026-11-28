# Rastreamento de erro: FORMAT_ERROR_BACKTRACE, FORMAT_CALL_STACK e UTL_CALL_STACK

`SQLCODE` e `SQLERRM` dizem **qual** erro aconteceu. Para corrigir, é preciso saber **onde**: em que unidade, em que linha, chamada por quem.

| Função | Mostra | Desde |
|---|---|---|
| `DBMS_UTILITY.FORMAT_ERROR_STACK` | A pilha de **erros** (ORA-20020, ORA-01476...), até 2000 bytes | 7 |
| `DBMS_UTILITY.FORMAT_ERROR_BACKTRACE` | O caminho do erro: unidade e **linha** onde foi levantado e por onde subiu | `[10g+]` |
| `DBMS_UTILITY.FORMAT_CALL_STACK` | A pilha de **chamadas** no momento (quem chamou quem), sem erro envolvido | 7 |
| `UTL_CALL_STACK` | As três coisas acima, item a item, sem precisar analisar texto | `[12c+]` |
| `$$PLSQL_UNIT`, `$$PLSQL_LINE` | Nome da unidade e linha atual, resolvidos na compilação | `[10g+]` |

## O backtrace e o RAISE no meio do caminho

O backtrace descreve o caminho do erro **a partir do último ponto em que ele foi levantado**. Se um tratador intermediário faz `RAISE;`, o backtrace capturado mais acima passa a apontar para a linha desse `RAISE`, e a linha original do erro pode se perder.

Regra prática: **registre o backtrace no primeiro tratador que pegar o erro**, antes de relançar. Ou não trate no meio: deixe subir até a camada que registra.

## UTL_CALL_STACK `[12c+]`

| Grupo | Funções | Para |
|---|---|---|
| Chamadas | `DYNAMIC_DEPTH`, `SUBPROGRAM(n)`, `CONCATENATE_SUBPROGRAM`, `UNIT_LINE(n)`, `OWNER(n)` | Saber de dentro de uma rotina quem a chamou |
| Erros | `ERROR_DEPTH`, `ERROR_NUMBER(n)`, `ERROR_MSG(n)` | Percorrer a pilha de erros |
| Backtrace | `BACKTRACE_DEPTH`, `BACKTRACE_UNIT(n)`, `BACKTRACE_LINE(n)` | Linha e unidade do erro, sem analisar texto |

A grande vantagem sobre `FORMAT_CALL_STACK`: `SUBPROGRAM` informa o nome da **rotina dentro da package** (`PKG_VENDAS.VALIDAR_CREDITO`), enquanto as funções de texto mostram só a package e a linha.

Nas funções de chamadas e de erros, o índice 1 é o mais recente (a rotina atual, o último erro levantado). No backtrace, não confie de memória em qual ponta é o índice 1: o script imprime todos os níveis ao lado do texto de `FORMAT_ERROR_BACKTRACE`, para conferir na sua versão qual índice traz a linha de origem.

## O que um log de erro deveria guardar

- Data e hora, usuário, sessão (`SYS_CONTEXT('USERENV', 'SID')`), módulo.
- Rotina (`$$PLSQL_UNIT` ou `UTL_CALL_STACK`) e parâmetros relevantes.
- `SQLCODE`, `FORMAT_ERROR_STACK` e `FORMAT_ERROR_BACKTRACE`.
- Gravado com transação autônoma (tópico 12).

Projetos prontos com essa estrutura: o **Logger** (OraOpenSource) é o mais usado.

## Documentação oficial

- [PL/SQL Packages and Types Reference — DBMS_UTILITY](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_UTILITY.html)
- [PL/SQL Packages and Types Reference — UTL_CALL_STACK](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/UTL_CALL_STACK.html)
- [PL/SQL Language Reference — Predefined Inquiry Directives](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-language-fundamentals.html)
