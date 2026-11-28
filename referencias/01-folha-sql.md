# Folha de consulta — SQL

Sintaxe resumida, para lembrar a forma. A explicação de cada item está na seção indicada. Exemplos sobre o schema de exemplo (`00-ambiente`).

## SELECT: escrita e ordem lógica

```sql
WITH base AS (...)                         -- 0  CTE (seção 02, tópico 08)
SELECT [DISTINCT] colunas, expressões      -- 5
  FROM tabela t                            -- 1
  JOIN outra o ON o.id = t.id              -- 1
 WHERE condição sobre linhas               -- 2
 GROUP BY colunas                          -- 3
HAVING condição sobre grupos               -- 4
 ORDER BY colunas [ASC|DESC] [NULLS FIRST|LAST]   -- 6
OFFSET n ROWS FETCH NEXT m ROWS ONLY;      -- 7  [12c+]
```

O `WHERE` não enxerga alias do `SELECT`; o `ORDER BY` enxerga. Função analítica é calculada depois do `HAVING` e antes do `ORDER BY` (seção 01, tópico 09).

## Joins (seção 05)

```sql
FROM a JOIN b ON b.id_a = a.id                    -- inner
FROM a LEFT JOIN b ON b.id_a = a.id               -- todos de a
FROM a LEFT JOIN b ON b.id_a = a.id AND b.x = 1   -- filtro de b no ON: mantém a sem par
FROM a FULL OUTER JOIN b ON b.id = a.id           -- todos dos dois lados
FROM a CROSS JOIN b                               -- produto cartesiano
FROM a JOIN b USING (id)                          -- coluna de mesmo nome, sem prefixo
FROM a CROSS JOIN LATERAL (SELECT ... WHERE x = a.x) l     -- [12c+]
FROM a OUTER APPLY (SELECT ... WHERE x = a.x FETCH FIRST 1 ROW ONLY) l  -- [12c+]
WHERE a.id = b.id_a(+)                            -- [legado] outer join antigo
```

Filtro sobre a tabela do lado opcional no `WHERE` transforma o `LEFT JOIN` em inner.

## Agregação e analíticas (seção 04, tópicos 06 a 09)

```sql
SELECT id_cliente, COUNT(*), SUM(x), AVG(x), MIN(x), MAX(x),
       COUNT(DISTINCT id_vendedor),
       LISTAGG(nome, ', ') WITHIN GROUP (ORDER BY nome),
       MAX(status) KEEP (DENSE_RANK LAST ORDER BY data_pedido)
  FROM ... GROUP BY id_cliente;

GROUP BY ROLLUP (a, b) | CUBE (a, b) | GROUPING SETS ((a), (b), ())

função() OVER (PARTITION BY ... ORDER BY ... ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
ROW_NUMBER() | RANK() | DENSE_RANK() | NTILE(4)
LAG(x [, n [, padrão]]) | LEAD(...) | FIRST_VALUE(x) | LAST_VALUE(x) | NTH_VALUE(x, n)
SUM(x) OVER (ORDER BY data)               -- acumulado (janela padrão: RANGE até a linha atual)
RATIO_TO_REPORT(x) OVER ()                -- fração do total
```

`COUNT(coluna)` ignora NULL; `COUNT(*)` não. `LAST_VALUE` com a janela padrão devolve a linha atual: use `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`.

## Subconsultas e conjuntos (seção 05, tópicos 05 e 06)

```sql
WHERE x IN (SELECT ...)            WHERE x NOT IN (SELECT ... WHERE col IS NOT NULL)
WHERE EXISTS (SELECT 1 FROM ... WHERE correlação)
WHERE x > ALL (SELECT ...)         WHERE x = ANY (SELECT ...)
SELECT (SELECT MAX(...) FROM ... WHERE correlação) AS escalar FROM ...

consulta UNION | UNION ALL | INTERSECT | MINUS consulta     -- [21c+] EXCEPT
```

`NOT IN` com um NULL na subconsulta devolve zero linhas; prefira `NOT EXISTS` (seção 15, caso 05).

## Hierarquia, recursão, pivot

```sql
-- CONNECT BY (seção 02, tópico 09)
SELECT LEVEL, LPAD(' ', 2 * (LEVEL - 1)) || nome, SYS_CONNECT_BY_PATH(nome, '/')
  FROM funcionarios
 START WITH id_gerente IS NULL
CONNECT BY PRIOR id_funcionario = id_gerente
 ORDER SIBLINGS BY nome;

-- CTE recursiva [11gR2+]
WITH h (id, nome, nivel) AS (
    SELECT id_funcionario, nome, 1 FROM funcionarios WHERE id_gerente IS NULL
    UNION ALL
    SELECT f.id_funcionario, f.nome, h.nivel + 1
      FROM funcionarios f JOIN h ON f.id_gerente = h.id
)
SELECT * FROM h;

-- Gerar linhas
SELECT LEVEL FROM dual CONNECT BY LEVEL <= 10;

-- PIVOT / UNPIVOT (seção 02, tópico 10)
SELECT * FROM (SELECT uf, tipo_pessoa FROM clientes)
 PIVOT (COUNT(*) FOR tipo_pessoa IN ('F' AS pf, 'J' AS pj));
```

## Condições e expressões (seção 03)

```sql
CASE WHEN cond THEN v1 WHEN cond2 THEN v2 ELSE v3 END
CASE expr WHEN 'A' THEN 1 WHEN 'B' THEN 2 END
DECODE(expr, 'A', 1, 'B', 2, 0)            -- DECODE trata NULL = NULL
x BETWEEN a AND b                          -- inclusivo nos dois lados
nome LIKE 'Pa%'   nome LIKE '%10\%%' ESCAPE '\'
REGEXP_LIKE(email, '^[^@]+@[^@]+$')
x IS NULL   x IS NOT NULL                  -- nunca  x = NULL
data >= DATE '2026-11-01' AND data < DATE '2026-12-01'   -- mês inteiro com hora
SYSDATE + 1   SYSDATE + INTERVAL '2' HOUR   ADD_MONTHS(d, 1)   d2 - d1  (dias)
```

## Funções mais usadas (seção 04)

| Grupo | Funções |
|---|---|
| Texto | `UPPER LOWER INITCAP LENGTH SUBSTR INSTR REPLACE TRANSLATE TRIM LTRIM RTRIM LPAD RPAD CONCAT \|\| REGEXP_SUBSTR REGEXP_REPLACE REGEXP_COUNT` |
| Número | `ROUND TRUNC CEIL FLOOR MOD REMAINDER ABS SIGN POWER SQRT GREATEST LEAST` |
| Data | `SYSDATE SYSTIMESTAMP CURRENT_DATE TRUNC(d, 'MM') ROUND(d) ADD_MONTHS MONTHS_BETWEEN LAST_DAY NEXT_DAY EXTRACT(YEAR FROM d)` |
| Conversão | `TO_CHAR TO_NUMBER TO_DATE TO_TIMESTAMP CAST(x AS tipo) VALIDATE_CONVERSION` `[12.2+]` (máscaras: [03](03-mascaras-de-formato.md)) |
| NULL | `NVL NVL2 COALESCE NULLIF LNNVL` |
| JSON | `JSON_VALUE JSON_QUERY JSON_TABLE JSON_EXISTS JSON_OBJECT JSON_ARRAYAGG` `[12c+]` |
| Outras | `ORA_HASH STANDARD_HASH SYS_GUID SYS_CONTEXT('USERENV', ...) USER UID` |

## DML (seção 06)

```sql
INSERT INTO t (a, b) VALUES (1, 'x');
INSERT INTO t (a, b) SELECT ... ;
INSERT ALL INTO t1 VALUES (...) INTO t2 VALUES (...) SELECT ... ;
UPDATE t SET a = 1, b = (SELECT ...) WHERE ... ;
UPDATE t SET ... WHERE ... RETURNING a INTO :v;
DELETE FROM t WHERE ... ;
TRUNCATE TABLE t;                                   -- DDL: sem rollback, sem WHERE

MERGE INTO destino d
USING origem o ON (d.id = o.id)
 WHEN MATCHED THEN UPDATE SET d.x = o.x WHERE DECODE(d.x, o.x, 0, 1) = 1
 WHEN NOT MATCHED THEN INSERT (id, x) VALUES (o.id, o.x);

INSERT ... LOG ERRORS INTO err$_t ('tag') REJECT LIMIT UNLIMITED;   -- tópico 10
```

## Transação e trava (seção 06, tópicos 06 a 09)

```sql
COMMIT;   ROLLBACK;   SAVEPOINT s1;   ROLLBACK TO s1;
SELECT ... FOR UPDATE [OF coluna] [NOWAIT | WAIT 5 | SKIP LOCKED];
LOCK TABLE t IN EXCLUSIVE MODE;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
```

DDL faz `COMMIT` antes e depois. No SQL*Plus, sair com `EXIT` confirma por padrão.

## DDL (seção 07)

```sql
CREATE TABLE t (
    id      NUMBER GENERATED ALWAYS AS IDENTITY CONSTRAINT pk_t PRIMARY KEY,   -- [12c+]
    codigo  VARCHAR2(20)  NOT NULL CONSTRAINT uk_t_codigo UNIQUE,
    valor   NUMBER(12,2)  DEFAULT 0 NOT NULL CONSTRAINT ck_t_valor CHECK (valor >= 0),
    id_pai  NUMBER        CONSTRAINT fk_t_pai REFERENCES pai (id) [ON DELETE CASCADE | SET NULL],
    total   AS (valor * 2)                                                    -- coluna virtual
);
ALTER TABLE t ADD (obs VARCHAR2(200));
ALTER TABLE t MODIFY (obs VARCHAR2(400));
ALTER TABLE t RENAME COLUMN obs TO observacao;
ALTER TABLE t DROP COLUMN observacao;
ALTER TABLE t ADD CONSTRAINT ... ;   ALTER TABLE t DISABLE | ENABLE [NOVALIDATE] CONSTRAINT nome;
CREATE [UNIQUE] INDEX ix ON t (a, b);   CREATE INDEX ix ON t (UPPER(nome));
CREATE OR REPLACE VIEW v AS SELECT ... [WITH CHECK OPTION | WITH READ ONLY];
CREATE MATERIALIZED VIEW mv REFRESH COMPLETE ON DEMAND AS SELECT ... ;
CREATE SEQUENCE s START WITH 1 INCREMENT BY 1 CACHE 20;   s.NEXTVAL   s.CURRVAL
CREATE GLOBAL TEMPORARY TABLE tmp (...) ON COMMIT DELETE ROWS;
CREATE [PUBLIC] SYNONYM sin FOR dono.objeto;
DROP TABLE t [CASCADE CONSTRAINTS] [PURGE];   FLASHBACK TABLE t TO BEFORE DROP;
COMMENT ON TABLE t IS '...';   COMMENT ON COLUMN t.c IS '...';
SELECT DBMS_METADATA.GET_DDL('TABLE', 'T') FROM dual;
```

## Privilégios (seção 13, tópico 04)

```sql
GRANT SELECT, INSERT ON t TO usuario;   GRANT EXECUTE ON pkg TO usuario;
GRANT CREATE TABLE TO usuario;          GRANT papel TO usuario;
REVOKE INSERT ON t FROM usuario;
```

## Plano de execução (seção 11)

```sql
EXPLAIN PLAN FOR SELECT ... ;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);

SELECT /*+ GATHER_PLAN_STATISTICS */ ... ;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR(NULL, NULL, 'ALLSTATS LAST'));

EXEC DBMS_STATS.GATHER_TABLE_STATS(USER, 'T')
```

## Dicionário (seção 10)

```sql
SELECT table_name FROM user_tables;
SELECT column_name, data_type, nullable FROM user_tab_columns WHERE table_name = 'T';
SELECT constraint_name, constraint_type FROM user_constraints WHERE table_name = 'T';
SELECT object_name, object_type, status FROM user_objects WHERE status = 'INVALID';
SELECT * FROM user_errors WHERE name = 'PKG';
SELECT * FROM dictionary WHERE table_name LIKE 'USER%IND%';
```
