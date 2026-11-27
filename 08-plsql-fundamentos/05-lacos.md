# Laços: LOOP, WHILE, FOR, EXIT e CONTINUE

## Formas

```sql
-- LOOP básico: repete até um EXIT
LOOP
    ...
    EXIT WHEN condicao;
END LOOP;

-- WHILE: testa antes de cada volta
WHILE condicao LOOP
    ...
END LOOP;

-- FOR numérico: contador automático
FOR i IN 1 .. 10 LOOP
    ...
END LOOP;

FOR i IN REVERSE 1 .. 10 LOOP      -- de 10 até 1
    ...
END LOOP;

-- FOR de cursor: uma volta por linha de uma consulta (tópico 08)
FOR r IN (SELECT ... FROM ...) LOOP
    ...
END LOOP;
```

## Regras do FOR numérico

- A variável do laço (`i`) é **declarada automaticamente** como `PLS_INTEGER`, existe só dentro do laço e **não pode ser alterada** (PLS-00363).
- Os limites são avaliados **uma vez**, no início. Mudar a variável usada como limite dentro do laço não muda a quantidade de voltas.
- Se o limite inferior for maior que o superior (`FOR i IN 10 .. 1`), o laço não executa nenhuma vez. Para contar para trás, `REVERSE` com os limites na ordem normal.
- Limite **NULL** não é zero voltas: dá VALUE_ERROR (ORA-06502). Acontece com `FOR i IN v_lista.FIRST .. v_lista.LAST` em coleção vazia (seção 09, tópico 07).
- Passo sempre 1. Para outros passos, multiplique (`i * 5`) ou use `WHILE`.

## EXIT e CONTINUE

| Comando | Efeito |
|---|---|
| `EXIT;` / `EXIT WHEN cond;` | Sai do laço |
| `CONTINUE;` / `CONTINUE WHEN cond;` `[11g+]` | Pula para a próxima volta |
| `EXIT rotulo;` | Sai de um laço externo, identificado por `<<rotulo>>` |

```sql
<<externo>>
FOR i IN 1 .. 10 LOOP
    FOR j IN 1 .. 10 LOOP
        EXIT externo WHEN i * j > 20;
    END LOOP;
END LOOP externo;
```

## Laço em PL/SQL versus SQL

Um laço que lê uma linha, faz um `UPDATE` e passa para a próxima é o padrão mais lento possível ("linha a linha"): cada volta troca de contexto entre PL/SQL e SQL. Antes de escrever o laço, veja se um `UPDATE`, `MERGE` ou `INSERT ... SELECT` resolve numa instrução só. Quando o laço é necessário (regra complexa por linha), processe em lote com `BULK COLLECT` e `FORALL` (seção 09).

## Armadilhas

- **Laço infinito**: `LOOP` sem `EXIT` alcançável, ou `WHILE` cuja condição nunca fica falsa (atenção a NULL: `WHILE v < 10` com `v` NULL nem começa; com `v` que vira NULL dentro do laço, para).
- **Commit dentro do laço** (seção 06, tópico 06).

## Documentação oficial

- [PL/SQL Language Reference — LOOP Statements](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-control-statements.html)
