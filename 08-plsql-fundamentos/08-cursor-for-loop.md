# Cursor FOR loop, cursores com parâmetro e WHERE CURRENT OF

## Cursor FOR loop

```sql
-- Consulta escrita no próprio laço
FOR r IN (SELECT id_cliente, nome FROM clientes WHERE uf = 'SP') LOOP
    DBMS_OUTPUT.PUT_LINE(r.nome);
END LOOP;

-- Cursor declarado antes
FOR r IN c_clientes LOOP
    ...
END LOOP;
```

O laço faz sozinho o que o tópico 07 faz à mão:

- declara o record `r` com a estrutura da consulta (existe só dentro do laço);
- abre o cursor, busca cada linha e fecha no fim;
- **fecha também se sair por `EXIT`, `RETURN` ou exceção**;
- a partir do 10g, com `PLSQL_OPTIMIZE_LEVEL` 2 (o padrão) ou maior, busca as linhas **de 100 em 100** por baixo, como um `BULK COLLECT LIMIT 100` implícito.

Por isso é a forma padrão de percorrer uma consulta em PL/SQL. A busca em lote ajuda na leitura, mas não no DML feito dentro do laço: um `UPDATE` por volta continua sendo uma troca de contexto por linha (para isso, `FORALL`, seção 09).

Colunas calculadas precisam de alias para virarem campo do record: `SELECT SUM(x) AS total ...` e depois `r.total`.

## Cursor com parâmetro

```sql
CURSOR c_clientes (p_uf clientes.uf%TYPE, p_ativo clientes.ativo%TYPE DEFAULT 'S') IS
    SELECT id_cliente, nome FROM clientes WHERE uf = p_uf AND ativo = p_ativo;

FOR r IN c_clientes('SP') LOOP ...
FOR r IN c_clientes('CE', 'N') LOOP ...
OPEN c_clientes(p_uf => 'MG');
```

- O parâmetro é só de entrada e não leva tamanho (`VARCHAR2`, não `VARCHAR2(2)`); `%TYPE` resolve isso.
- Aceita `DEFAULT` e notação nomeada.
- O mesmo cursor pode ser aberto várias vezes com valores diferentes (uma vez por volta de um laço externo, por exemplo).
- Parâmetro funciona como bind variable: a consulta é compartilhada entre as execuções.

Laço de cursor dentro de laço de cursor (para cada departamento, buscar os funcionários) é o padrão N+1: uma consulta por linha do laço externo. Funciona e aparece muito, mas um JOIN com GROUP BY ou um único cursor ordenado costuma resolver com uma ida ao banco.

## FOR UPDATE e WHERE CURRENT OF

```sql
CURSOR c IS
    SELECT id_produto, preco_unitario
      FROM produtos
     WHERE id_categoria = 2
       FOR UPDATE OF preco_unitario NOWAIT;
...
UPDATE produtos SET preco_unitario = ... WHERE CURRENT OF c;
```

- `FOR UPDATE` trava as linhas do resultado **no OPEN**, antes da primeira busca. Outras sessões que tentarem alterá-las esperam.
- `OF coluna` indica de quais tabelas travar (importa quando há JOIN: só a tabela da coluna citada é travada).
- `NOWAIT` falha na hora com ORA-00054 se alguma linha estiver travada; `WAIT n` espera até n segundos; `SKIP LOCKED` pula as travadas (útil em fila de processamento).
- `WHERE CURRENT OF c` altera a linha que acabou de ser buscada, pelo ROWID, sem repetir a condição.

**COMMIT dentro do laço de um cursor FOR UPDATE** libera as travas e invalida o cursor: a busca seguinte dá ORA-01002 (busca fora de sequência). Grave no fim, ou não use FOR UPDATE se for gravar em partes.

Locks e espera entre sessões: seção 06, tópico 08.

## Documentação oficial

- [PL/SQL Language Reference — Cursor FOR LOOP Statement](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/cursor-FOR-LOOP-statement.html)
- [PL/SQL Language Reference — Explicit Cursors that Accept Parameters](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/static-sql.html)
- [SQL Language Reference — SELECT, for_update_clause](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SELECT.html)
