# Linguagem procedural: PL/SQL × PL/pgSQL × T-SQL × MySQL

PL/pgSQL foi desenhado à imagem do PL/SQL: a estrutura de bloco, `DECLARE`, `BEGIN`, `EXCEPTION`, `:=`, `%TYPE` e `%ROWTYPE` são familiares. T-SQL (SQL Server) é outra família, em que procedimento e consulta se misturam no mesmo lote. O MySQL tem uma linguagem de procedures simples, próxima do padrão SQL/PSM.

## A mesma procedure nos quatro

Reajustar os preços de uma categoria, recusar reajuste acima de 50% e devolver quantos produtos mudaram.

**Oracle (PL/SQL)**

```sql
CREATE OR REPLACE PROCEDURE reajustar_categoria (
    p_id_categoria IN  NUMBER,
    p_pct          IN  NUMBER,
    p_qtd          OUT NUMBER
) IS
BEGIN
    IF p_pct > 50 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Reajuste de ' || p_pct || '% acima do limite');
    END IF;

    UPDATE produtos
       SET preco_unitario = ROUND(preco_unitario * (1 + p_pct / 100), 2)
     WHERE id_categoria = p_id_categoria;

    p_qtd := SQL%ROWCOUNT;
END;
/
```

**PostgreSQL (PL/pgSQL)**

```sql
CREATE OR REPLACE PROCEDURE reajustar_categoria (
    p_id_categoria integer,
    p_pct          numeric,
    INOUT p_qtd    integer DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_pct > 50 THEN
        RAISE EXCEPTION 'Reajuste de % acima do limite', p_pct || '%';
    END IF;

    UPDATE produtos
       SET preco_unitario = ROUND(preco_unitario * (1 + p_pct / 100), 2)
     WHERE id_categoria = p_id_categoria;

    GET DIAGNOSTICS p_qtd = ROW_COUNT;
END;
$$;

CALL reajustar_categoria(5, 10);
```

No `RAISE`, cada `%` da mensagem é substituído pelo argumento seguinte (aqui, o percentual já com o símbolo; `%%` escreveria o caractere literal). O corpo vai entre `$$` (*dollar quoting*), para não precisar dobrar as aspas.

**SQL Server (T-SQL)**

```sql
CREATE OR ALTER PROCEDURE dbo.reajustar_categoria
    @id_categoria int,
    @pct          decimal(5,2),
    @qtd          int OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @pct > 50
        THROW 50001, 'Reajuste acima do limite', 1;

    UPDATE dbo.produtos
       SET preco_unitario = ROUND(preco_unitario * (1 + @pct / 100), 2)
     WHERE id_categoria = @id_categoria;

    SET @qtd = @@ROWCOUNT;
END;
GO

DECLARE @n int;
EXEC dbo.reajustar_categoria 5, 10, @n OUTPUT;
SELECT @n;
```

**MySQL**

```sql
DELIMITER //

CREATE PROCEDURE reajustar_categoria (
    IN  p_id_categoria INT,
    IN  p_pct          DECIMAL(5,2),
    OUT p_qtd          INT
)
BEGIN
    IF p_pct > 50 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Reajuste acima do limite';
    END IF;

    UPDATE produtos
       SET preco_unitario = ROUND(preco_unitario * (1 + p_pct / 100), 2)
     WHERE id_categoria = p_id_categoria;

    SET p_qtd = ROW_COUNT();
END //

DELIMITER ;

CALL reajustar_categoria(5, 10, @n);
SELECT @n;
```

`DELIMITER` é comando do cliente `mysql`, para o `;` de dentro da procedure não encerrar o `CREATE` (o papel do `/` no SQL*Plus e do `GO` no SQL Server).

## Quadro de equivalências

| Recurso | Oracle | PostgreSQL | SQL Server | MySQL |
|---|---|---|---|---|
| Bloco anônimo | `BEGIN ... END;` | `DO $$ BEGIN ... END $$;` | O próprio lote de comandos | Não há (só dentro de procedure) |
| Variável | Seção `DECLARE`, `v NUMBER;` | Seção `DECLARE`, `v numeric;` | `DECLARE @v int;` em qualquer ponto | `DECLARE v INT;` no início do bloco |
| Atribuição | `v := 1;` | `v := 1;` | `SET @v = 1;` ou `SELECT @v = col FROM ...` | `SET v = 1;` |
| Linha para variável | `SELECT ... INTO v` | `SELECT ... INTO v` (`STRICT` para exigir uma linha) | `SELECT @v = col ...` | `SELECT ... INTO v` |
| Linhas afetadas | `SQL%ROWCOUNT` | `GET DIAGNOSTICS n = ROW_COUNT` | `@@ROWCOUNT` | `ROW_COUNT()` |
| Laço em consulta | `FOR r IN (SELECT ...) LOOP` | `FOR r IN SELECT ... LOOP` | Cursor com `WHILE @@FETCH_STATUS = 0` (ou, melhor, uma instrução SQL) | Cursor com `DECLARE CONTINUE HANDLER FOR NOT FOUND` |
| Tratar erro | `EXCEPTION WHEN ... THEN` | `EXCEPTION WHEN ... THEN` | `BEGIN TRY ... END TRY BEGIN CATCH ... END CATCH` | `DECLARE ... HANDLER FOR SQLEXCEPTION` |
| Levantar erro | `RAISE_APPLICATION_ERROR` | `RAISE EXCEPTION` | `THROW` (`RAISERROR` `[legado]`) | `SIGNAL SQLSTATE '45000'` |
| Mensagem do erro | `SQLERRM`, `SQLCODE` | `SQLERRM`, `SQLSTATE` | `ERROR_MESSAGE()`, `ERROR_NUMBER()` | `GET DIAGNOSTICS CONDITION 1` |
| Saída de depuração | `DBMS_OUTPUT.PUT_LINE` | `RAISE NOTICE` | `PRINT` | `SELECT` |
| Package | Sim | Não (schemas e extensões organizam) | Não | Não |
| Function que devolve tabela | Pipelined (seção 09, tópico 11) | `RETURNS TABLE (...)` / `SETOF` | Table-valued function (inline ou multi-statement) | Não |
| COMMIT dentro da rotina | Procedure e function | Só em **procedure** (11+); function não | Sim | Sim |
| Transação autônoma | `PRAGMA AUTONOMOUS_TRANSACTION` | Não nativo (extensões ou dblink) | Não nativo | Não |
| SQL dinâmico | `EXECUTE IMMEDIATE ... USING` | `EXECUTE format(...) USING` | `sp_executesql` com parâmetros | `PREPARE` / `EXECUTE ... USING` |
| Outras linguagens no banco | Java, JavaScript `[23ai+]` | PL/Python, PL/Perl, PL/v8 e outras | .NET (CLR) | Não (JavaScript no MySQL HeatWave e Enterprise 9.x) |

## Triggers

| | Oracle | PostgreSQL | SQL Server | MySQL |
|---|---|---|---|---|
| Estrutura | O trigger contém o código | Uma **function** `RETURNS trigger` + o `CREATE TRIGGER` que a chama | O trigger contém o código | O trigger contém o código |
| De linha | `FOR EACH ROW`, `:NEW`, `:OLD` | `FOR EACH ROW`, `NEW`, `OLD`; `RETURN NEW` | **Não há**: só de instrução | Só de linha, `NEW.col`, `OLD.col` |
| De instrução | Sim | `FOR EACH STATEMENT` (com tabelas de transição `REFERENCING NEW TABLE`) | Sim, com as pseudotabelas `inserted` e `deleted` (todas as linhas afetadas) | Não |
| `INSTEAD OF` | Em views | Em views | Em tabelas e views | Não |

O trigger do SQL Server roda **uma vez por instrução** e precisa tratar `inserted` como conjunto. Trigger escrito supondo uma linha (`SELECT @id = id FROM inserted`) funciona no teste e erra em silêncio quando um `UPDATE` atinge várias linhas: é um dos bugs mais comuns em código T-SQL.

## Documentação

- [Oracle — PL/SQL Language Reference](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/index.html)
- [PostgreSQL — PL/pgSQL](https://www.postgresql.org/docs/current/plpgsql.html)
- [PostgreSQL — Porting from Oracle PL/SQL](https://www.postgresql.org/docs/current/plpgsql-porting.html)
- [SQL Server — Transact-SQL reference](https://learn.microsoft.com/sql/t-sql/language-reference)
- [MySQL — Compound Statement Syntax](https://dev.mysql.com/doc/refman/8.4/en/sql-compound-statements.html)
