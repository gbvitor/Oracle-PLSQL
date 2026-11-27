-- =============================================================================
-- Tópico : Tabela mutante (ORA-04091) e compound trigger
-- Seção  : 09-plsql-avancado
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); CREATE TRIGGER
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

CREATE TABLE tmp_pedidos AS SELECT id_pedido, id_cliente, status FROM pedidos;
ALTER TABLE tmp_pedidos ADD valor_total NUMBER(12,2);

CREATE TABLE tmp_itens AS SELECT * FROM itens_pedido;
CREATE INDEX tmp_ix_itens_pedido ON tmp_itens (id_pedido);

UPDATE tmp_pedidos p
   SET valor_total = (SELECT SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2))
                        FROM tmp_itens i
                       WHERE i.id_pedido = p.id_pedido);
COMMIT;

-- Esperado: 1045.5 | 16276.5
SELECT id_pedido, valor_total FROM tmp_pedidos WHERE id_pedido IN (1001, 1002) ORDER BY id_pedido;

-- 1. A tentativa ingênua: trigger de linha que soma a própria tabela.
CREATE OR REPLACE TRIGGER tmp_trg_itens_total
    AFTER INSERT OR UPDATE OR DELETE ON tmp_itens
    FOR EACH ROW
DECLARE
    v_total NUMBER;
BEGIN
    SELECT SUM(ROUND(quantidade * preco_unitario * (1 - pct_desconto / 100), 2))
      INTO v_total
      FROM tmp_itens
     WHERE id_pedido = NVL(:NEW.id_pedido, :OLD.id_pedido);

    UPDATE tmp_pedidos SET valor_total = v_total WHERE id_pedido = NVL(:NEW.id_pedido, :OLD.id_pedido);
END;
/

-- Esperado: ORA-04091 (a tabela ESTUDO.TMP_ITENS é mutante...), ORA-06512, ORA-04088
UPDATE tmp_itens SET pct_desconto = 10 WHERE id_pedido = 1001;

-- O mesmo com INSERT ... SELECT de uma linha só: também mutante.
-- Esperado: ORA-04091
INSERT INTO tmp_itens
SELECT 1001, 4, 1, 2, 39.90, 0 FROM dual;

DROP TRIGGER tmp_trg_itens_total;

-- 2. Compound trigger: a linha anota, a instrução recalcula.
CREATE OR REPLACE TRIGGER tmp_trg_itens_total
    FOR INSERT OR UPDATE OR DELETE ON tmp_itens
    COMPOUND TRIGGER

    TYPE t_ids IS TABLE OF BOOLEAN INDEX BY PLS_INTEGER;
    g_pedidos t_ids;

    AFTER EACH ROW IS
    BEGIN
        IF :OLD.id_pedido IS NOT NULL THEN
            g_pedidos(:OLD.id_pedido) := TRUE;
        END IF;
        IF :NEW.id_pedido IS NOT NULL THEN
            g_pedidos(:NEW.id_pedido) := TRUE;
        END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
        v_id PLS_INTEGER;
    BEGIN
        v_id := g_pedidos.FIRST;
        WHILE v_id IS NOT NULL LOOP
            UPDATE tmp_pedidos p
               SET valor_total = (SELECT SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2))
                                    FROM tmp_itens i
                                   WHERE i.id_pedido = p.id_pedido)
             WHERE p.id_pedido = v_id;

            DBMS_OUTPUT.PUT_LINE('[recalculado pedido ' || v_id || ']');
            v_id := g_pedidos.NEXT(v_id);
        END LOOP;
    END AFTER STATEMENT;

END tmp_trg_itens_total;
/

-- 2a. UPDATE de 3 itens do mesmo pedido: um recálculo só.
UPDATE tmp_itens SET pct_desconto = 10 WHERE id_pedido = 1001;
-- Esperado: [recalculado pedido 1001] (uma vez, não três)

-- Esperado: 952.2 (538.2 + 189 + 225)
SELECT valor_total FROM tmp_pedidos WHERE id_pedido = 1001;

-- 2b. INSERT ... SELECT, que antes dava ORA-04091.
INSERT INTO tmp_itens
SELECT 1001, 4, 1, 2, 39.90, 0 FROM dual;

-- Esperado: 1032 (952.2 + 79.8)
SELECT valor_total FROM tmp_pedidos WHERE id_pedido = 1001;

-- 2c. DELETE do item.
DELETE FROM tmp_itens WHERE id_pedido = 1001 AND nr_item = 4;

-- Esperado: 952.2
SELECT valor_total FROM tmp_pedidos WHERE id_pedido = 1001;

-- 2d. Uma instrução que toca dois pedidos.
UPDATE tmp_itens SET pct_desconto = 0 WHERE id_pedido IN (1001, 1002);
-- Esperado: [recalculado pedido 1001] | [recalculado pedido 1002]

-- Esperado: 1001 1058 | 1002 17802
SELECT id_pedido, valor_total FROM tmp_pedidos WHERE id_pedido IN (1001, 1002) ORDER BY id_pedido;

-- 2e. Item que muda de pedido: os dois totais são recalculados.
UPDATE tmp_itens SET id_pedido = 1002, nr_item = 9 WHERE id_pedido = 1001 AND nr_item = 3;
-- Esperado: [recalculado pedido 1001] | [recalculado pedido 1002]

-- Esperado: 1001 808 (1058 - 250) | 1002 18052 (17802 + 250)
SELECT id_pedido, valor_total FROM tmp_pedidos WHERE id_pedido IN (1001, 1002) ORDER BY id_pedido;

ROLLBACK;

-- 3. A conferência que vale para qualquer desnormalização: total guardado bate com o calculado?
-- Esperado: nenhuma linha
SELECT p.id_pedido, p.valor_total, c.calculado
  FROM tmp_pedidos p
  JOIN (SELECT id_pedido,
               SUM(ROUND(quantidade * preco_unitario * (1 - pct_desconto / 100), 2)) AS calculado
          FROM tmp_itens
         GROUP BY id_pedido) c
    ON c.id_pedido = p.id_pedido
 WHERE p.valor_total <> c.calculado;

DROP TABLE tmp_itens   PURGE;
DROP TABLE tmp_pedidos PURGE;
