-- =============================================================================
-- Tópico : Functions — uso em SQL, restrições, DETERMINISTIC, RESULT_CACHE,
--          PRAGMA UDF e WITH FUNCTION
-- Seção  : 09-plsql-avancado
-- Versão : 19c (passos 8 e 9 exigem 12c+)
-- Requer : schema de exemplo (00-ambiente); CREATE PROCEDURE
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- 1. Function de valor líquido do pedido.
CREATE OR REPLACE FUNCTION tmp_fn_valor_pedido (p_id_pedido IN pedidos.id_pedido%TYPE)
    RETURN NUMBER
IS
    v_total NUMBER;
BEGIN
    SELECT SUM(ROUND(quantidade * preco_unitario * (1 - pct_desconto / 100), 2))
      INTO v_total
      FROM itens_pedido
     WHERE id_pedido = p_id_pedido;

    RETURN v_total;
END tmp_fn_valor_pedido;
/

-- Esperado: 1008 27286 | 1020 16832.88 | 1002 16276.5 | 1014 15962.7 | 1017 7554.28
SELECT id_pedido, tmp_fn_valor_pedido(id_pedido) AS valor
  FROM pedidos
 ORDER BY valor DESC
 FETCH FIRST 5 ROWS ONLY;

-- A mesma consulta sem function: um JOIN com GROUP BY, uma ida só aos itens.
SELECT p.id_pedido,
       SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
  FROM pedidos p
  JOIN itens_pedido i ON i.id_pedido = p.id_pedido
 GROUP BY p.id_pedido
 ORDER BY valor DESC
 FETCH FIRST 5 ROWS ONLY;

-- Pedido inexistente: o SUM devolve NULL, não há NO_DATA_FOUND.
-- Esperado: NULL
SELECT tmp_fn_valor_pedido(9999) AS valor FROM dual;

-- 2. Uso em PL/SQL, como expressão.
BEGIN
    IF tmp_fn_valor_pedido(1001) > 1000 THEN
        DBMS_OUTPUT.PUT_LINE('1001 passa de 1000: ' || tmp_fn_valor_pedido(1001));
    END IF;
END;
/
-- Esperado: 1001 passa de 1000: 1045.5

-- 3. Function sem RETURN em algum caminho.
CREATE OR REPLACE FUNCTION tmp_fn_faixa (p_valor NUMBER) RETURN VARCHAR2 IS
BEGIN
    IF p_valor >= 10000 THEN
        RETURN 'GRANDE';
    ELSIF p_valor >= 1000 THEN
        RETURN 'MEDIO';
    END IF;
END tmp_fn_faixa;
/

-- Esperado: GRANDE | MEDIO | depois ORA-06503 (a função retornou sem valor) no 500
SELECT tmp_fn_faixa(27286) FROM dual;
SELECT tmp_fn_faixa(1045.5) FROM dual;
SELECT tmp_fn_faixa(500) FROM dual;

-- Corrigida, e marcada como DETERMINISTIC (só depende da entrada).
CREATE OR REPLACE FUNCTION tmp_fn_faixa (p_valor NUMBER) RETURN VARCHAR2
    DETERMINISTIC
IS
BEGIN
    RETURN CASE
               WHEN p_valor >= 10000 THEN 'GRANDE'
               WHEN p_valor >= 1000  THEN 'MEDIO'
               ELSE 'PEQUENO'
           END;
END tmp_fn_faixa;
/

-- Esperado: GRANDE 4 | PEQUENO 6 | MEDIO 14
SELECT tmp_fn_faixa(tmp_fn_valor_pedido(id_pedido)) AS faixa, COUNT(*) AS qtd
  FROM pedidos
 GROUP BY tmp_fn_faixa(tmp_fn_valor_pedido(id_pedido))
 ORDER BY qtd;

-- 4. Restrições de function chamada por SQL.
CREATE TABLE tmp_log (momento TIMESTAMP DEFAULT SYSTIMESTAMP, texto VARCHAR2(200));

CREATE OR REPLACE FUNCTION tmp_fn_com_dml (p_id NUMBER) RETURN NUMBER IS
BEGIN
    INSERT INTO tmp_log (texto) VALUES ('consultou ' || p_id);
    RETURN p_id;
END tmp_fn_com_dml;
/

-- Esperado: ORA-14551 (não é possível executar uma operação DML dentro de uma consulta)
SELECT tmp_fn_com_dml(1) FROM dual;

-- Em PL/SQL, a mesma function funciona.
DECLARE
    v NUMBER;
BEGIN
    v := tmp_fn_com_dml(1);
    DBMS_OUTPUT.PUT_LINE('Em PL/SQL: ok, ' || v);
END;
/
-- Esperado: Em PL/SQL: ok, 1

ROLLBACK;

CREATE OR REPLACE FUNCTION tmp_fn_com_out (p_id IN NUMBER, p_dobro OUT NUMBER) RETURN NUMBER IS
BEGIN
    p_dobro := p_id * 2;
    RETURN p_id;
END tmp_fn_com_out;
/

-- Esperado: ORA-06572 (a função TMP_FN_COM_OUT tem argumentos de saída)
SELECT tmp_fn_com_out(1, NULL) FROM dual;

-- 5. Quantas vezes a function é chamada: uma por linha.
--    DBMS_OUTPUT é permitido em function chamada por SQL (não é DML).
CREATE OR REPLACE FUNCTION tmp_fn_eco (p_id NUMBER) RETURN NUMBER IS
BEGIN
    DBMS_OUTPUT.PUT_LINE('  chamada com ' || p_id);
    RETURN p_id;
END tmp_fn_eco;
/

-- Esperado: 4 linhas de resultado e 4 "chamada com 1" (uma por pedido do cliente 1)
SELECT id_pedido, tmp_fn_eco(id_cliente) AS cliente FROM pedidos WHERE id_cliente = 1;

-- Com subconsulta escalar, entrada repetida costuma vir do cache.
-- Esperado: 4 linhas e normalmente uma só "chamada com 1" (o cache não é garantido)
SELECT id_pedido, (SELECT tmp_fn_eco(id_cliente) FROM dual) AS cliente FROM pedidos WHERE id_cliente = 1;

-- 6. Índice baseado em função exige DETERMINISTIC.
CREATE TABLE tmp_pedidos AS SELECT * FROM pedidos;

-- Esperado: ORA-30553 (a função não é determinística)
CREATE INDEX tmp_ix_eco ON tmp_pedidos (tmp_fn_eco(id_cliente));

-- tmp_fn_faixa é DETERMINISTIC: o índice é aceito (a coluna escolhida é só para
-- mostrar a regra; o índice não tem uso prático aqui).
CREATE INDEX tmp_ix_faixa ON tmp_pedidos (tmp_fn_faixa(id_pedido));

-- 7. RESULT_CACHE: cache compartilhado entre sessões.
CREATE OR REPLACE FUNCTION tmp_fn_nome_categoria (p_id categorias.id_categoria%TYPE)
    RETURN VARCHAR2
    RESULT_CACHE
IS
    v_nome categorias.nome%TYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('  executou o corpo para ' || p_id);
    SELECT nome INTO v_nome FROM categorias WHERE id_categoria = p_id;
    RETURN v_nome;
END tmp_fn_nome_categoria;
/

BEGIN
    DBMS_OUTPUT.PUT_LINE('1a: ' || tmp_fn_nome_categoria(5));
    DBMS_OUTPUT.PUT_LINE('2a: ' || tmp_fn_nome_categoria(5));
END;
/
-- Esperado, com o result cache ligado:
--     executou o corpo para 5
--   1a: Papelaria
--   2a: Papelaria
--   (a segunda chamada não executa o corpo; com o cache desligado, as duas executam)

-- Ver se o result cache está ligado (precisa de leitura em V$/parâmetros).
-- Esperado: RESULT_CACHE_MAX_SIZE maior que 0 e RESULT_CACHE_MODE = MANUAL
SELECT name, value FROM v$parameter WHERE name IN ('result_cache_max_size', 'result_cache_mode');

-- 8. [12c+] WITH FUNCTION: function que existe só nesta consulta.
--    No SQL*Plus, a consulta com WITH FUNCTION termina com "/", não com ";".
WITH
    FUNCTION liquido (p_qtd NUMBER, p_preco NUMBER, p_desc NUMBER) RETURN NUMBER IS
    BEGIN
        RETURN ROUND(p_qtd * p_preco * (1 - p_desc / 100), 2);
    END;
SELECT id_pedido, nr_item, liquido(quantidade, preco_unitario, pct_desconto) AS valor
  FROM itens_pedido
 WHERE id_pedido = 1001
 ORDER BY nr_item
/
-- Esperado: 1 598 | 2 210 | 3 237.5

-- 9. [12c+] PRAGMA UDF: mesma function, compilada para chamada a partir de SQL.
CREATE OR REPLACE FUNCTION tmp_fn_liquido (p_qtd NUMBER, p_preco NUMBER, p_desc NUMBER)
    RETURN NUMBER
IS
    PRAGMA UDF;
BEGIN
    RETURN ROUND(p_qtd * p_preco * (1 - p_desc / 100), 2);
END tmp_fn_liquido;
/

-- Esperado: 122815.43 (total geral dos itens)
SELECT SUM(tmp_fn_liquido(quantidade, preco_unitario, pct_desconto)) AS total FROM itens_pedido;

DROP INDEX tmp_ix_faixa;
DROP TABLE tmp_pedidos PURGE;
DROP TABLE tmp_log PURGE;
DROP FUNCTION tmp_fn_liquido;
DROP FUNCTION tmp_fn_nome_categoria;
DROP FUNCTION tmp_fn_eco;
DROP FUNCTION tmp_fn_com_out;
DROP FUNCTION tmp_fn_com_dml;
DROP FUNCTION tmp_fn_faixa;
DROP FUNCTION tmp_fn_valor_pedido;
