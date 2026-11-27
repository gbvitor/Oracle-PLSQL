# SQL dinâmico: EXECUTE IMMEDIATE, bind variables, DBMS_ASSERT e DBMS_SQL

SQL estático (o escrito direto no código PL/SQL) é verificado na compilação: tabelas, colunas e tipos precisam existir. SQL dinâmico é um **texto montado em tempo de execução**. Serve quando o texto não é conhecido na compilação:

- DDL dentro de PL/SQL (`CREATE`, `ALTER`, `TRUNCATE`, `GRANT`), que não pode ser estático;
- nome de tabela ou coluna que vem de parâmetro;
- filtros opcionais escolhidos pelo usuário;
- colunas que variam (PIVOT com valores descobertos na hora).

Fora desses casos, prefira SQL estático: erro aparece na compilação, dependências ficam registradas (tópico 15) e não há risco de injeção.

## EXECUTE IMMEDIATE

```sql
EXECUTE IMMEDIATE 'TRUNCATE TABLE tmp_carga';

EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM pedidos WHERE status = :s'
    INTO v_qtd
    USING p_status;

EXECUTE IMMEDIATE 'UPDATE produtos SET preco_unitario = preco_unitario * :f WHERE id_categoria = :c'
    USING p_fator, p_categoria;

EXECUTE IMMEDIATE 'BEGIN tmp_proc(:a, :b); END;'
    USING IN v_entrada, OUT v_saida;
```

- O texto **não leva `;` no fim** quando é uma instrução SQL (ORA-00933 ou ORA-00911). Quando é um bloco PL/SQL, leva o `END;`.
- `INTO` para uma linha (as mesmas exceções do SELECT INTO); `BULK COLLECT INTO` para várias.
- `USING` passa os valores dos placeholders (`:nome`). Modos `IN` (padrão), `OUT`, `IN OUT`.
- `RETURNING ... INTO` funciona como no estático.
- DDL dinâmico faz COMMIT implícito, como qualquer DDL.

## Bind variable, não concatenação

```sql
-- Errado: valor concatenado no texto
EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM clientes WHERE uf = ''' || p_uf || '''' INTO v_qtd;

-- Certo: valor passado como bind
EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM clientes WHERE uf = :uf' INTO v_qtd USING p_uf;
```

Concatenar valores causa dois problemas:

1. **SQL injection**: `p_uf = 'SP'' OR ''1''=''1'` transforma o filtro em "verdadeiro para todas as linhas". Com bind, o valor é só um valor, nunca vira parte do comando.
2. **Parse a cada valor**: cada texto diferente é uma instrução nova no shared pool (hard parse). Com bind, o mesmo texto é reaproveitado. O script mostra 100 instruções contra 1 em `V$SQL`.

Regras dos placeholders:

- Em SQL dinâmico, a associação é **por posição**: `:x` repetido duas vezes precisa de dois valores no `USING` (senão ORA-01008).
- Em bloco PL/SQL dinâmico, é **por nome**: `:x` repetido recebe um valor só.
- `USING NULL` literal não é aceito; passe uma variável que vale NULL.
- Bind substitui **valor**, nunca nome de tabela, coluna ou palavra-chave.

## Quando o nome precisa ser concatenado: DBMS_ASSERT

| Função | Garante |
|---|---|
| `DBMS_ASSERT.SIMPLE_SQL_NAME(x)` | `x` é um identificador válido (ORA-44003 se não for) |
| `DBMS_ASSERT.SQL_OBJECT_NAME(x)` | `x` é um objeto que existe (ORA-44002 se não existir) |
| `DBMS_ASSERT.ENQUOTE_NAME(x)` | Põe entre aspas duplas (e em maiúsculas, por padrão) |
| `DBMS_ASSERT.ENQUOTE_LITERAL(x)` | Põe entre aspas simples, recusando aspas soltas no meio |

Melhor ainda que validar o formato: conferir contra uma lista do que é permitido (`USER_TABLES`, uma tabela de configuração, um `CASE`).

## Filtros opcionais

Montar o `WHERE` só com os filtros informados, mantendo binds e o mesmo número de placeholders, com o truque da condição neutra:

```sql
v_sql := 'SELECT COUNT(*) FROM clientes WHERE 1 = 1';

IF p_uf IS NOT NULL THEN
    v_sql := v_sql || ' AND uf = :uf';
ELSE
    v_sql := v_sql || ' AND (1 = 1 OR :uf IS NULL)';
END IF;
```

O `USING` passa sempre todos os valores; o filtro não informado vira uma condição que o otimizador descarta. Resultado: no máximo 2^n textos diferentes para n filtros, todos com bind, cada um com o plano certo para os filtros que usa.

## DBMS_SQL

API de baixo nível, para quando nem o número de colunas nem o de binds é conhecido na compilação: descrever as colunas de uma consulta qualquer (`DESCRIBE_COLUMNS`), montar binds em laço, gerar CSV de qualquer SELECT. Converte de e para `REF CURSOR` (`TO_REFCURSOR`, `TO_CURSOR_NUMBER`) `[11g+]`.

`DBMS_SQL.RETURN_RESULT` `[12c+]` devolve um cursor aberto como **resultado implícito** para o cliente (SQL*Plus, SQL Developer, JDBC), como uma procedure do SQL Server que devolve um SELECT.

## Documentação oficial

- [PL/SQL Language Reference — PL/SQL Dynamic SQL](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/dynamic-sql.html)
- [PL/SQL Language Reference — EXECUTE IMMEDIATE Statement](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/EXECUTE-IMMEDIATE-statement.html)
- [PL/SQL Packages and Types Reference — DBMS_ASSERT](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_ASSERT.html)
- [PL/SQL Packages and Types Reference — DBMS_SQL](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_SQL.html)
