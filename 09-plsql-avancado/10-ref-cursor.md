# REF CURSOR e SYS_REFCURSOR

Um cursor explícito (seção 08) está preso a uma consulta fixa e não sai do bloco onde foi declarado. Uma **variável de cursor** (`REF CURSOR`) é um ponteiro para um cursor aberto: pode receber consultas diferentes, ser passada como parâmetro e ser devolvida para o programa que chamou, inclusive fora do banco (Java, .NET, Python, SQL*Plus).

É a forma padrão de uma procedure **devolver um conjunto de linhas** para a aplicação.

## Fraco e forte

```sql
-- Fraco: aceita qualquer consulta. SYS_REFCURSOR é o tipo fraco predefinido.
v_rc SYS_REFCURSOR;

-- Forte: a estrutura do resultado é fixa e verificada na compilação.
TYPE t_rc_pedidos IS REF CURSOR RETURN pedidos%ROWTYPE;
v_rc t_rc_pedidos;
```

| | Fraco (`SYS_REFCURSOR`) | Forte (`RETURN ...`) |
|---|---|---|
| Consultas aceitas | Qualquer uma, inclusive texto dinâmico | Só as que devolvem a estrutura declarada |
| Erro de estrutura | Em tempo de execução, no FETCH (ROWTYPE_MISMATCH, ORA-06504) | Na compilação (PLS-00382) |
| `OPEN FOR` com texto dinâmico | Sim | Não |
| Uso típico | Devolver resultado à aplicação; consulta montada na hora | API interna PL/SQL com contrato fixo |

## Abrir, buscar, fechar

```sql
OPEN v_rc FOR SELECT id_pedido, status FROM pedidos WHERE id_cliente = p_id;

OPEN v_rc FOR 'SELECT id_pedido, status FROM pedidos WHERE id_cliente = :id' USING p_id;

LOOP
    FETCH v_rc INTO v_id, v_status;
    EXIT WHEN v_rc%NOTFOUND;
    ...
END LOOP;
CLOSE v_rc;
```

- `OPEN FOR` numa variável já aberta fecha a anterior e abre a nova.
- Os atributos (`%FOUND`, `%NOTFOUND`, `%ROWCOUNT`, `%ISOPEN`) são os do cursor explícito.
- `FETCH ... BULK COLLECT INTO ... LIMIT n` funciona igual.
- Não existe cursor FOR loop sobre variável de cursor: é OPEN/FETCH/CLOSE.

## Quem fecha

Quem **consome** o cursor fecha. A procedure que abre e devolve não fecha (o cliente ainda vai ler). O cliente que lê e não fecha deixa cursores abertos na sessão até estourar `OPEN_CURSORS` (ORA-01000), problema clássico em aplicação com pool de conexões.

## Restrições

- Variável de cursor **não pode** ser declarada no nível da package (PLS-00994); só dentro de rotinas. O **tipo** `REF CURSOR` pode ser declarado na especificação da package.
- Não pode ser usada em SQL diretamente, nem gravada em tabela.
- `REF CURSOR` não tem `FOR UPDATE` implícito nem `WHERE CURRENT OF`.

## Alternativas para devolver linhas

| Recurso | Quando |
|---|---|
| `SYS_REFCURSOR` em parâmetro `OUT` ou `RETURN` | Aplicação consome as linhas |
| `DBMS_SQL.RETURN_RESULT` `[12c+]` | Resultado implícito, sem parâmetro (tópico 09) |
| Pipelined table function | O resultado precisa ser usado **em SQL** (`SELECT * FROM TABLE(f(...))`, tópico 11) |
| Coleção | Volume pequeno, já em memória |

## Documentação oficial

- [PL/SQL Language Reference — Cursor Variables](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/static-sql.html)
- [PL/SQL Language Reference — OPEN FOR Statement](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/OPEN-FOR-statement.html)
