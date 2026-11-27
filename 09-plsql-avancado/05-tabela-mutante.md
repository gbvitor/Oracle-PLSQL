# Tabela mutante (ORA-04091) e compound trigger

## O erro

Um trigger **de linha** não pode consultar nem alterar a tabela que está sendo modificada pela instrução que o disparou:

```
ORA-04091: a tabela ESTUDO.TMP_ITENS é mutante; talvez o gatilho/função não possa localizá-la
```

O motivo: no meio da instrução, a tabela está pela metade. Num `UPDATE` de 3 linhas, quando o trigger roda para a linha 2, a linha 1 já mudou e a 3 ainda não. Qualquer `SELECT SUM(...)` ali leria um estado que nunca existiu de fato. O Oracle prefere recusar a devolver um resultado que depende da ordem de processamento.

Onde aparece:

- Trigger `FOR EACH ROW` que faz `SELECT` na própria tabela (somar itens para atualizar o total do pedido, checar duplicidade, contar registros).
- Function chamada por um `UPDATE`/`DELETE` que lê a tabela alterada.
- Tabela pai com FK `ON DELETE CASCADE`: a tabela filha também fica mutante durante o DELETE do pai.

Exceção conhecida: `INSERT ... VALUES` de **uma linha** não torna a tabela mutante para os triggers de linha (`INSERT ... SELECT`, mesmo que traga uma linha só, torna). Um trigger que funciona no teste com uma linha e quebra na primeira carga em lote costuma ser isso.

Triggers **de instrução** não têm a restrição: quando o `AFTER STATEMENT` roda, a instrução já terminou e a tabela está consistente.

## A solução: compound trigger `[11g+]`

Um compound trigger tem as quatro seções de momento num objeto só, com **declarações compartilhadas** entre elas durante a instrução:

```sql
CREATE OR REPLACE TRIGGER trg_itens_total
    FOR INSERT OR UPDATE OR DELETE ON itens_pedido
    COMPOUND TRIGGER

    TYPE t_ids IS TABLE OF BOOLEAN INDEX BY PLS_INTEGER;
    g_pedidos t_ids;

    AFTER EACH ROW IS
    BEGIN
        -- só anota quais pedidos foram tocados
        g_pedidos(NVL(:NEW.id_pedido, :OLD.id_pedido)) := TRUE;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
        v_id PLS_INTEGER;
    BEGIN
        -- a tabela já está consistente: pode consultar
        v_id := g_pedidos.FIRST;
        WHILE v_id IS NOT NULL LOOP
            UPDATE pedidos SET valor_total = (SELECT SUM(...) FROM itens_pedido WHERE id_pedido = v_id)
             WHERE id_pedido = v_id;
            v_id := g_pedidos.NEXT(v_id);
        END LOOP;
    END AFTER STATEMENT;
END trg_itens_total;
/
```

- A linha só **anota**; o trabalho com a tabela fica para o `AFTER STATEMENT`.
- A coleção indexada pelo próprio id elimina repetição: um UPDATE de 3 itens do mesmo pedido recalcula o pedido uma vez.
- Num UPDATE que muda a chave (`id_pedido` de um item), anote o `:OLD` e o `:NEW`: os dois pedidos mudaram de total.
- O estado começa vazio a cada instrução e é descartado se a instrução falhar.
- Em instrução que afeta milhões de linhas, a coleção cresce em memória (PGA); o padrão é descarregar a cada N linhas no próprio `AFTER EACH ROW`.

Antes do 11g, a mesma solução exigia três triggers e uma package para guardar a lista entre eles. Ainda aparece em código antigo.

## Antes de criar o trigger

Guardar o total no pedido é **desnormalização**: o mesmo dado em dois lugares, mantido por código. Alternativas a considerar:

- Calcular na hora, numa view ou numa consulta (com índice em `itens_pedido(id_pedido)`, é barato).
- Materialized view com refresh (seção 07).
- Atualizar o total na mesma procedure que grava os itens, em vez de trigger.

O trigger se justifica quando muitos caminhos diferentes gravam itens e não há como garantir que todos chamem a mesma procedure.

## Documentação oficial

- [PL/SQL Language Reference — Mutating-Table Restriction](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-triggers.html)
- [PL/SQL Language Reference — Compound DML Triggers](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-triggers.html)
