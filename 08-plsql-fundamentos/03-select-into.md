# SELECT INTO, NO_DATA_FOUND e TOO_MANY_ROWS

## Forma

```sql
SELECT nome, uf
  INTO v_nome, v_uf
  FROM clientes
 WHERE id_cliente = p_id;
```

Lê **exatamente uma linha** para variáveis (ou para um registro `%ROWTYPE`). A quantidade e a ordem das colunas precisam bater com as variáveis.

## As duas exceções

| Situação | Exceção | SQLCODE |
|---|---|---|
| Nenhuma linha | `NO_DATA_FOUND` (ORA-01403) | **+100** |
| Mais de uma linha | `TOO_MANY_ROWS` (ORA-01422) | -1422 |

Não são erros de programação em si: são a forma de o banco avisar que a premissa "existe exatamente um" não se confirmou. O código decide o que fazer, e decidir é obrigatório: deixar estourar ou tratar.

```sql
BEGIN
    SELECT nome INTO v_nome FROM clientes WHERE id_cliente = p_id;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- ou: RAISE_APPLICATION_ERROR(-20001, 'Cliente ' || p_id || ' não existe');
        v_nome := NULL;
    WHEN TOO_MANY_ROWS THEN
        RAISE_APPLICATION_ERROR(-20002, 'Mais de um cliente com o mesmo critério');
END;
```

## Agregação nunca dá NO_DATA_FOUND

`SELECT COUNT(*) INTO ...` e `SELECT MAX(...) INTO ...` sem `GROUP BY` sempre devolvem **uma linha** (com 0 ou NULL). Por isso, "existe?" é melhor respondido com `COUNT(*)` ou `MAX` do que com `SELECT INTO` e tratamento de `NO_DATA_FOUND`:

```sql
SELECT COUNT(*) INTO v_qtd FROM pedidos WHERE id_cliente = p_id AND ROWNUM = 1;
```

O `ROWNUM = 1` faz o banco parar na primeira linha encontrada.

## NO_DATA_FOUND silencioso em função chamada por SQL

Se uma **function** PL/SQL levanta `NO_DATA_FOUND` e não trata, e ela foi chamada de dentro de um comando SQL (`SELECT minha_funcao(x) FROM ...`), o SQL **não** recebe o erro: a função simplesmente devolve NULL. O mesmo código chamado de PL/SQL dá erro. É uma das fontes mais difíceis de bug em relatórios. Nas funções usadas em SQL, trate `NO_DATA_FOUND` explicitamente.

## Alternativas

- `RETURNING ... INTO` para ler o resultado de um DML (seção 02, tópico 12).
- Cursor explícito com um `FETCH` para "a primeira, se houver" sem exceção (tópico 07).
- `BULK COLLECT INTO` para várias linhas (seção 09).

## Documentação oficial

- [PL/SQL Language Reference — SELECT INTO Statement](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/SELECT-INTO-statement.html)
