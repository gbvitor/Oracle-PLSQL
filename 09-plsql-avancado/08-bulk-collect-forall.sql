-- =============================================================================
-- Tópico : BULK COLLECT, LIMIT, FORALL, SQL%BULK_ROWCOUNT, SAVE EXCEPTIONS
-- Seção  : 09-plsql-avancado
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- 1. BULK COLLECT em coleção de records.
DECLARE
    TYPE t_clientes IS TABLE OF clientes%ROWTYPE INDEX BY PLS_INTEGER;
    v_clientes t_clientes;
BEGIN
    SELECT * BULK COLLECT INTO v_clientes FROM clientes ORDER BY id_cliente;
    DBMS_OUTPUT.PUT_LINE('Carregados: ' || v_clientes.COUNT);
    DBMS_OUTPUT.PUT_LINE('Primeiro: ' || v_clientes(1).nome || ' | Último: ' || v_clientes(v_clientes.COUNT).nome);
END;
/
-- Esperado: Carregados: 12 | Primeiro: Papelaria Central Ltda | Último: Thiago Nunes

-- 2. Sem linhas: coleção vazia, sem exceção.
DECLARE
    TYPE t_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    v_ids t_ids;
BEGIN
    SELECT id_cliente BULK COLLECT INTO v_ids FROM clientes WHERE uf = 'AM';
    DBMS_OUTPUT.PUT_LINE('Clientes no AM: ' || v_ids.COUNT || ' (sem NO_DATA_FOUND)');
END;
/
-- Esperado: Clientes no AM: 0 (sem NO_DATA_FOUND)

-- 3. LIMIT: o teste certo e o teste que perde o último lote.
DECLARE
    CURSOR c IS SELECT id_pedido FROM pedidos ORDER BY id_pedido;
    TYPE t_ids IS TABLE OF pedidos.id_pedido%TYPE INDEX BY PLS_INTEGER;
    v_lote  t_ids;
    v_total PLS_INTEGER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('-- EXIT WHEN v_lote.COUNT = 0');
    OPEN c;
    LOOP
        FETCH c BULK COLLECT INTO v_lote LIMIT 10;
        EXIT WHEN v_lote.COUNT = 0;
        DBMS_OUTPUT.PUT_LINE('lote de ' || v_lote.COUNT || ': ' || v_lote(1) || ' a ' || v_lote(v_lote.COUNT));
        v_total := v_total + v_lote.COUNT;
    END LOOP;
    CLOSE c;
    DBMS_OUTPUT.PUT_LINE('processados: ' || v_total);

    DBMS_OUTPUT.PUT_LINE('-- EXIT WHEN c%NOTFOUND (errado)');
    v_total := 0;
    OPEN c;
    LOOP
        FETCH c BULK COLLECT INTO v_lote LIMIT 10;
        EXIT WHEN c%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('lote de ' || v_lote.COUNT);
        v_total := v_total + v_lote.COUNT;
    END LOOP;
    CLOSE c;
    DBMS_OUTPUT.PUT_LINE('processados: ' || v_total || ' (faltaram ' || v_lote.COUNT || ')');
END;
/
-- Esperado:
--   -- EXIT WHEN v_lote.COUNT = 0
--   lote de 10: 1001 a 1010
--   lote de 10: 1011 a 1020
--   lote de 4: 1021 a 1024
--   processados: 24
--   -- EXIT WHEN c%NOTFOUND (errado)
--   lote de 10
--   lote de 10
--   processados: 20 (faltaram 4)

-- 4. FORALL com SQL%BULK_ROWCOUNT.
CREATE TABLE tmp_produtos AS SELECT * FROM produtos;

DECLARE
    TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    v_categorias t_num;
    v_fatores    t_num;
BEGIN
    v_categorias(1) := 2;  v_fatores(1) := 1.05;
    v_categorias(2) := 3;  v_fatores(2) := 1.03;
    v_categorias(3) := 5;  v_fatores(3) := 1.10;
    v_categorias(4) := 99; v_fatores(4) := 2;

    FORALL i IN 1 .. v_categorias.COUNT
        UPDATE tmp_produtos
           SET preco_unitario = ROUND(preco_unitario * v_fatores(i), 2)
         WHERE id_categoria = v_categorias(i);

    DBMS_OUTPUT.PUT_LINE('Total: ' || SQL%ROWCOUNT);
    FOR i IN 1 .. v_categorias.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE('categoria ' || v_categorias(i) || ': ' || SQL%BULK_ROWCOUNT(i));
    END LOOP;
END;
/
-- Esperado: Total: 11 | categoria 2: 5 | categoria 3: 3 | categoria 5: 3 | categoria 99: 0

ROLLBACK;

-- 5. RETURNING BULK COLLECT INTO.
DECLARE
    TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    v_ids    t_num;
    v_precos t_num;
BEGIN
    UPDATE tmp_produtos
       SET preco_unitario = ROUND(preco_unitario * 1.05, 2)
     WHERE id_categoria = 5
    RETURNING id_produto, preco_unitario BULK COLLECT INTO v_ids, v_precos;

    FOR i IN 1 .. v_ids.COUNT LOOP
        DBMS_OUTPUT.PUT_LINE(v_ids(i) || ' -> ' || v_precos(i));
    END LOOP;
END;
/
-- Esperado (a ordem pode variar): 8 -> 34.13 | 9 -> 47.25 | 10 -> 29.19

ROLLBACK;

-- 6. INDICES OF: FORALL sobre coleção esparsa.
DECLARE
    TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    v_novo_preco t_num;
BEGIN
    v_novo_preco(1)  := 40;
    v_novo_preco(9)  := 46;
    v_novo_preco(13) := 799;

    FORALL i IN INDICES OF v_novo_preco
        UPDATE tmp_produtos SET preco_unitario = v_novo_preco(i) WHERE id_produto = i;

    DBMS_OUTPUT.PUT_LINE('Atualizados: ' || SQL%ROWCOUNT);
END;
/
-- Esperado: Atualizados: 3 (índices 1, 9 e 13 usados como id_produto)

ROLLBACK;

-- 7. Erro no FORALL: sem e com SAVE EXCEPTIONS.
CREATE TABLE tmp_destino (
    id NUMBER CONSTRAINT pk_tmp_destino PRIMARY KEY
              CONSTRAINT ck_tmp_destino CHECK (id > 0)
);

-- 7a. Sem SAVE EXCEPTIONS: para no primeiro erro; o que veio antes fica.
DECLARE
    TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    v t_num;
BEGIN
    v(1) := 1;  v(2) := 2;  v(3) := 2;  v(4) := 3;  v(5) := -1;

    FORALL i IN 1 .. v.COUNT
        INSERT INTO tmp_destino VALUES (v(i));
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        DBMS_OUTPUT.PUT_LINE('Parou no primeiro erro: ' || SQLERRM);
END;
/
-- Esperado: Parou no primeiro erro: ORA-00001 ...

-- Esperado: 2 (os ids 1 e 2; o 3 nem foi tentado)
SELECT COUNT(*) FROM tmp_destino;

ROLLBACK;

-- 7b. Com SAVE EXCEPTIONS: executa todos e relata os que falharam.
DECLARE
    TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    v t_num;

    e_erros_em_lote EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_erros_em_lote, -24381);
BEGIN
    v(1) := 1;  v(2) := 2;  v(3) := 2;  v(4) := 3;  v(5) := -1;

    FORALL i IN 1 .. v.COUNT SAVE EXCEPTIONS
        INSERT INTO tmp_destino VALUES (v(i));
EXCEPTION
    WHEN e_erros_em_lote THEN
        DBMS_OUTPUT.PUT_LINE('Falhas: ' || SQL%BULK_EXCEPTIONS.COUNT);
        FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE('  índice ' || SQL%BULK_EXCEPTIONS(j).ERROR_INDEX
                || ' (valor ' || v(SQL%BULK_EXCEPTIONS(j).ERROR_INDEX) || '): '
                || SQLERRM(-SQL%BULK_EXCEPTIONS(j).ERROR_CODE));
        END LOOP;
END;
/
-- Esperado:
--   Falhas: 2
--     índice 3 (valor 2): ORA-00001: restrição exclusiva (.) violada
--     índice 5 (valor -1): ORA-02290: restrição de verificação (.) violada
--   (SQLERRM pelo código não sabe o nome da constraint; o texto depende do idioma)

-- Esperado: 3 (ids 1, 2 e 3)
SELECT COUNT(*) FROM tmp_destino;

ROLLBACK;
DROP TABLE tmp_destino PURGE;

-- 8. Linha a linha versus FORALL: 100 mil linhas.
CREATE TABLE tmp_carga (id NUMBER, valor NUMBER);

DECLARE
    TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
    v_ids    t_num;
    v_valores t_num;
    v_inicio PLS_INTEGER;
BEGIN
    FOR i IN 1 .. 100000 LOOP
        v_ids(i)     := i;
        v_valores(i) := MOD(i, 997);
    END LOOP;

    v_inicio := DBMS_UTILITY.GET_TIME;
    FOR i IN 1 .. v_ids.COUNT LOOP
        INSERT INTO tmp_carga VALUES (v_ids(i), v_valores(i));
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Linha a linha: ' || (DBMS_UTILITY.GET_TIME - v_inicio) / 100 || ' s');

    ROLLBACK;

    v_inicio := DBMS_UTILITY.GET_TIME;
    FORALL i IN 1 .. v_ids.COUNT
        INSERT INTO tmp_carga VALUES (v_ids(i), v_valores(i));
    DBMS_OUTPUT.PUT_LINE('FORALL:        ' || (DBMS_UTILITY.GET_TIME - v_inicio) / 100 || ' s');

    ROLLBACK;
END;
/
-- Esperado: FORALL com uma fração do tempo do laço (tipicamente 10 a 50 vezes
--           menos; os números dependem da máquina)

DROP TABLE tmp_carga PURGE;
DROP TABLE tmp_produtos PURGE;
