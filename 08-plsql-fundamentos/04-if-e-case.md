# IF, ELSIF, ELSE e CASE em PL/SQL

## IF

```sql
IF condicao THEN
    ...
ELSIF outra_condicao THEN      -- ELSIF, sem o segundo E
    ...
ELSE
    ...
END IF;
```

- Só entra no ramo se a condição for **TRUE**. NULL (desconhecido) vai para o `ELSE`, como `FALSE`.
- `IF v_valor <> 0 THEN ... ELSE ...`: com `v_valor` NULL, executa o `ELSE`, que normalmente foi escrito pensando no zero. Trate o NULL antes ou explicitamente.

## CASE como comando

```sql
CASE v_status
    WHEN 'ABERTO'   THEN ...;
    WHEN 'FATURADO' THEN ...;
    ELSE ...;
END CASE;

CASE
    WHEN v_valor > 10000 THEN ...;
    WHEN v_valor > 1000  THEN ...;
END CASE;
```

Diferença importante em relação ao `CASE` **expressão** (seção 03, tópico 02): o comando `CASE` sem `ELSE`, quando nenhum `WHEN` é verdadeiro, **levanta `CASE_NOT_FOUND`** (ORA-06592). A expressão `CASE` sem `ELSE` devolve NULL.

O erro é proposital: força o programador a considerar todos os casos. Se não fazer nada é aceitável, escreva `ELSE NULL;`.

## CASE como expressão em PL/SQL

Para atribuir valor, a expressão é mais curta:

```sql
v_faixa := CASE WHEN v_valor > 10000 THEN 'grande'
                WHEN v_valor > 1000  THEN 'medio'
                ELSE 'pequeno' END;
```

## Curto-circuito

PL/SQL avalia `AND` e `OR` da esquerda para a direita e **para** assim que o resultado está definido. Diferente do `WHERE` em SQL, em que a ordem não é garantida (seção 02, tópico 03). Assim é seguro escrever:

```sql
IF v_divisor <> 0 AND v_total / v_divisor > 10 THEN ...
IF v_lista IS NOT NULL AND v_lista.COUNT > 0 THEN ...
```

## Documentação oficial

- [PL/SQL Language Reference — Conditional Selection Statements](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-control-statements.html)
