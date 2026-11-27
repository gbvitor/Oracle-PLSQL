# Cursores explícitos: OPEN, FETCH, CLOSE

Um cursor explícito é uma consulta com nome, declarada na seção `DECLARE`, que você abre, percorre e fecha no seu ritmo. Serve quando a consulta devolve várias linhas e o `SELECT INTO` (uma linha só) não basta.

```sql
DECLARE
    CURSOR c_pedidos IS
        SELECT id_pedido, status FROM pedidos WHERE id_cliente = 1;
    r c_pedidos%ROWTYPE;
BEGIN
    OPEN c_pedidos;
    LOOP
        FETCH c_pedidos INTO r;
        EXIT WHEN c_pedidos%NOTFOUND;
        -- processa r
    END LOOP;
    CLOSE c_pedidos;
END;
```

## Ciclo de vida

| Etapa | O que acontece |
|---|---|
| `OPEN` | Executa a consulta e fixa o resultado no ponto de leitura daquele instante (consistência de leitura, seção 06 tópico 07). Mudanças feitas depois, mesmo pela própria sessão, não aparecem nas linhas buscadas. |
| `FETCH` | Traz a próxima linha para as variáveis ou o record. Quando acabam as linhas, as variáveis **mantêm o último valor** e `%NOTFOUND` vira `TRUE`. |
| `CLOSE` | Libera o cursor. Buscar depois disso dá `INVALID_CURSOR` (ORA-01001). |

## Atributos

| Atributo | Antes do OPEN | Depois do OPEN, antes do 1º FETCH | Depois de um FETCH com linha | Depois do FETCH sem linha |
|---|---|---|---|---|
| `%ISOPEN` | FALSE | TRUE | TRUE | TRUE |
| `%FOUND` | ORA-01001 | NULL | TRUE | FALSE |
| `%NOTFOUND` | ORA-01001 | NULL | FALSE | TRUE |
| `%ROWCOUNT` | ORA-01001 | 0 | Linhas buscadas até agora | Total buscado |

## A armadilha da última linha repetida

`EXIT WHEN c%NOTFOUND` vem **logo depois** do `FETCH`, antes de usar as variáveis. Se ficar no fim do laço, a volta em que o FETCH não traz nada ainda processa as variáveis, que guardam a linha anterior. Resultado: a última linha é processada duas vezes. O script mostra o caso.

Pelo mesmo motivo, `WHILE c%FOUND LOOP` exige um FETCH antes do laço e outro no fim de cada volta.

## Cursor explícito ou cursor FOR loop?

Na maior parte do código, o **cursor FOR loop** (tópico 08) é melhor: abre, busca e fecha sozinho, inclusive se der exceção, e busca de 100 em 100 por baixo. O ciclo manual se justifica quando:

- é preciso controlar quando buscar (ler uma linha, decidir, talvez parar no meio);
- o processamento é em lote com `FETCH ... BULK COLLECT INTO ... LIMIT n` (seção 09, tópico 08);
- o cursor vai ser passado adiante como `REF CURSOR` (seção 09, tópico 10).

## Fechar sempre, inclusive no erro

Um cursor declarado num bloco anônimo ou numa procedure fecha sozinho quando o bloco termina. Um cursor declarado **em package** fica aberto na sessão até alguém fechar; esquecer abertos leva a ORA-01000 (máximo de cursores abertos excedido). O hábito seguro é fechar também no tratador de exceção:

```sql
EXCEPTION
    WHEN OTHERS THEN
        IF c_pedidos%ISOPEN THEN
            CLOSE c_pedidos;
        END IF;
        RAISE;
```

## Documentação oficial

- [PL/SQL Language Reference — Explicit Cursors](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/static-sql.html)
- [PL/SQL Language Reference — Explicit Cursor Attribute](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/explicit-cursor-attribute.html)
