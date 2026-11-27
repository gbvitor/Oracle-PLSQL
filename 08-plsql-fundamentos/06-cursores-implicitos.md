# Cursores implícitos: SQL%ROWCOUNT, SQL%FOUND, SQL%NOTFOUND

Toda instrução SQL executada diretamente no corpo do PL/SQL (`SELECT INTO`, `INSERT`, `UPDATE`, `DELETE`, `MERGE`) usa um **cursor implícito**, que o Oracle abre e fecha sozinho. O resultado da **última** dessas instruções fica disponível pelos atributos `SQL%`.

## Atributos

| Atributo | Depois de DML | Depois de `SELECT INTO` |
|---|---|---|
| `SQL%ROWCOUNT` | Linhas afetadas (0 se nenhuma) | 1 em caso de sucesso |
| `SQL%FOUND` | `TRUE` se afetou ao menos 1 linha | `TRUE` |
| `SQL%NOTFOUND` | `TRUE` se afetou 0 linhas | Não chega a ser testado: a exceção NO_DATA_FOUND desvia antes |
| `SQL%ISOPEN` | Sempre `FALSE` (o cursor fecha ao fim da instrução) | Sempre `FALSE` |

Enquanto nenhuma instrução SQL tiver sido executada, os três primeiros valem NULL.

Atributos extras para `FORALL` (`SQL%BULK_ROWCOUNT`, `SQL%BULK_EXCEPTIONS`) ficam na seção 09, tópico 08.

## Pontos que confundem

**UPDATE e DELETE que não acham nada não dão erro.** Diferente do `SELECT INTO`, nenhum DML levanta NO_DATA_FOUND. Se "nenhuma linha" é um erro na sua regra, teste `SQL%ROWCOUNT` e levante a exceção você mesmo.

**O valor é da última instrução SQL, de qualquer lugar.** Uma chamada a procedure que execute SQL por dentro troca o valor. Guarde em variável logo depois da instrução que interessa:

```sql
UPDATE ...;
v_qtd := SQL%ROWCOUNT;
registrar_log(...);
DBMS_OUTPUT.PUT_LINE(v_qtd);
```

**`SQL%ROWCOUNT` só existe em PL/SQL.** No SQL*Plus, o equivalente é a mensagem "n linhas atualizadas" (controlada por `SET FEEDBACK`).

**MERGE**: `SQL%ROWCOUNT` traz o total de linhas afetadas, sem separar inseridas de atualizadas.

## Padrão "atualiza, se não achou insere"

```sql
UPDATE estoque SET qtd = qtd + p_qtd WHERE id_produto = p_id;

IF SQL%ROWCOUNT = 0 THEN
    INSERT INTO estoque (id_produto, qtd) VALUES (p_id, p_qtd);
END IF;
```

Funciona, mas tem corrida entre sessões: duas sessões podem não achar a linha ao mesmo tempo e as duas tentarem o INSERT (uma recebe ORA-00001 se houver chave). `MERGE` faz o mesmo em uma instrução (seção 06, tópico 05), mas também não elimina a corrida; a chave primária é o que garante que não haverá duplicata.

## Documentação oficial

- [PL/SQL Language Reference — Implicit Cursors](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/static-sql.html)
- [PL/SQL Language Reference — Implicit Cursor Attribute](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/implicit-cursor-attribute.html)
