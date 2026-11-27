# RAISE, RAISE_APPLICATION_ERROR, SQLCODE e SQLERRM

## RAISE

| Forma | Onde | Efeito |
|---|---|---|
| `RAISE e_nome;` | Em qualquer lugar | Levanta a exceção nomeada (do usuário ou predefinida) |
| `RAISE;` | **Só dentro de um tratador** | Relança a exceção que está sendo tratada, com o código original |

`RAISE;` é o fim natural de um `WHEN OTHERS` que registra o erro: o registro fica feito e o chamador continua sabendo que falhou.

## RAISE_APPLICATION_ERROR

```sql
RAISE_APPLICATION_ERROR(numero, mensagem [, manter_pilha]);
```

- `numero` entre **-20000 e -20999**. Fora dessa faixa, o próprio RAISE_APPLICATION_ERROR falha (ORA-21000).
- `mensagem` com até 2048 bytes.
- `manter_pilha`: `FALSE` (padrão) substitui a pilha de erros pela sua mensagem; `TRUE` acrescenta sua mensagem por cima e preserva os erros anteriores. Use `TRUE` quando estiver traduzindo um erro técnico em mensagem de negócio e quiser manter a causa original visível para quem depura.

Diferença para exceção do usuário: o erro chega ao chamador (aplicação, SQL*Plus, Java, job) com código ORA-20xxx e o texto que você escreveu, em vez do genérico ORA-06510 (exceção definida pelo usuário não tratada).

Combine com `PRAGMA EXCEPTION_INIT(e, -20010)` no chamador para tratar por nome um erro de aplicação específico (o script mostra).

Uma convenção simples, mantida numa package: faixas de número por módulo (-20100 a -20199 vendas, -20200 a -20299 estoque, ...) e o número documentado junto da mensagem.

## SQLCODE e SQLERRM

| Situação | `SQLCODE` | `SQLERRM` |
|---|---|---|
| Fora de tratador (sem erro) | 0 | `ORA-0000: normal, successful completion` |
| Erro Oracle | Negativo (`-1476`) | `ORA-01476: o divisor é igual a zero` |
| NO_DATA_FOUND | **+100** | `ORA-01403: dados não encontrados` |
| Exceção do usuário | **+1** | `User-Defined Exception` |
| RAISE_APPLICATION_ERROR | O número passado (`-20010`) | `ORA-20010: <sua mensagem>` |

Os textos das mensagens Oracle seguem o idioma da sessão (`NLS_LANGUAGE`); os códigos não mudam.

- `SQLERRM(codigo)` devolve a mensagem de qualquer código, sem precisar do erro: `SQLERRM(-1422)`.
- **Não podem ser usadas direto numa instrução SQL**. Copie para variáveis antes do `INSERT` no log.
- `SQLERRM` corta em 512 bytes. Para a pilha completa, `DBMS_UTILITY.FORMAT_ERROR_STACK`.
- Nenhuma das duas informa **a linha** onde o erro aconteceu. Isso é `DBMS_UTILITY.FORMAT_ERROR_BACKTRACE` `[10g+]`, ou `UTL_CALL_STACK` `[12c+]` (seção 09, tópico 13).

## Registrar e relançar

O padrão de tratamento em código de produção:

```sql
EXCEPTION
    WHEN OTHERS THEN
        v_codigo   := SQLCODE;
        v_mensagem := DBMS_UTILITY.FORMAT_ERROR_STACK || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        registrar_erro('processar_pedido', v_codigo, v_mensagem);
        RAISE;
END;
```

Atenção: se `registrar_erro` fizer um `INSERT` comum, ele é desfeito junto com o resto quando o erro sobe sem tratamento até o cliente (atomicidade da chamada, tópico 11). O log só sobrevive se `registrar_erro` usar `PRAGMA AUTONOMOUS_TRANSACTION` (seção 09, tópico 12). O script demonstra o log sumindo.

## Documentação oficial

- [PL/SQL Language Reference — RAISE Statement](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/RAISE-statement.html)
- [PL/SQL Language Reference — Raising Exceptions Explicitly](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-error-handling.html)
- [PL/SQL Language Reference — SQLCODE Function](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/SQLCODE-function.html)
- [PL/SQL Language Reference — SQLERRM Function](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/SQLERRM-function.html)
