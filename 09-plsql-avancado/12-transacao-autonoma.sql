-- =============================================================================
-- Tópico : PRAGMA AUTONOMOUS_TRANSACTION — log que sobrevive ao ROLLBACK,
--          isolamento, ORA-06519, deadlock consigo mesmo
-- Seção  : 09-plsql-avancado
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); CREATE PROCEDURE
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

CREATE TABLE tmp_log_erro (
    momento  TIMESTAMP DEFAULT SYSTIMESTAMP,
    rotina   VARCHAR2(100),
    codigo   NUMBER,
    mensagem VARCHAR2(4000)
);

CREATE TABLE tmp_dados (id NUMBER, descricao VARCHAR2(50));

-- 1. Procedure de log autônoma.
CREATE OR REPLACE PROCEDURE tmp_registrar_erro (
    p_rotina   IN VARCHAR2,
    p_codigo   IN NUMBER,
    p_mensagem IN VARCHAR2
) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO tmp_log_erro (rotina, codigo, mensagem) VALUES (p_rotina, p_codigo, p_mensagem);
    COMMIT;
END tmp_registrar_erro;
/

-- 2. Registrar e relançar: agora o log sobrevive.
--    (Na seção 08, tópico 10, com INSERT comum, o log sumia.)
DECLARE
    v_zero PLS_INTEGER := 0;
    v_num  NUMBER;
BEGIN
    INSERT INTO tmp_dados VALUES (1, 'gravado antes do erro');
    v_num := 1 / v_zero;
EXCEPTION
    WHEN OTHERS THEN
        tmp_registrar_erro('passo 2', SQLCODE,
                           DBMS_UTILITY.FORMAT_ERROR_STACK || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        RAISE;
END;
/
-- Esperado: ORA-01476 chega ao SQL*Plus

-- Esperado: dados 0 (desfeito com a chamada) | log 1 (transação própria, já confirmada)
SELECT (SELECT COUNT(*) FROM tmp_dados)    AS dados,
       (SELECT COUNT(*) FROM tmp_log_erro) AS log
  FROM dual;

-- Esperado: passo 2 | -1476 | ORA-01476 ... ORA-06512 ... linha
SELECT rotina, codigo, SUBSTR(mensagem, 1, 120) AS mensagem FROM tmp_log_erro;

-- 3. ROLLBACK do chamador não desfaz o COMMIT da rotina autônoma.
BEGIN
    INSERT INTO tmp_dados VALUES (2, 'transação principal');
    tmp_registrar_erro('passo 3', 0, 'registro de execução');
    ROLLBACK;
END;
/

-- Esperado: dados 0 | log 2
SELECT (SELECT COUNT(*) FROM tmp_dados)    AS dados,
       (SELECT COUNT(*) FROM tmp_log_erro) AS log
  FROM dual;

-- 4. A rotina autônoma não enxerga o que o chamador não confirmou.
CREATE OR REPLACE FUNCTION tmp_fn_conta_dados_autonoma RETURN NUMBER IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    v NUMBER;
BEGIN
    SELECT COUNT(*) INTO v FROM tmp_dados;
    COMMIT;
    RETURN v;
END tmp_fn_conta_dados_autonoma;
/

DECLARE
    v_principal NUMBER;
BEGIN
    INSERT INTO tmp_dados VALUES (3, 'ainda sem COMMIT');
    SELECT COUNT(*) INTO v_principal FROM tmp_dados;
    DBMS_OUTPUT.PUT_LINE('Transação principal vê: ' || v_principal);
    DBMS_OUTPUT.PUT_LINE('Rotina autônoma vê:     ' || tmp_fn_conta_dados_autonoma);
    ROLLBACK;
END;
/
-- Esperado: Transação principal vê: 1 | Rotina autônoma vê: 0

-- 5. Sair sem COMMIT nem ROLLBACK: ORA-06519.
CREATE OR REPLACE PROCEDURE tmp_proc_esqueceu_commit IS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO tmp_dados VALUES (4, 'sem commit');
END tmp_proc_esqueceu_commit;
/

BEGIN
    tmp_proc_esqueceu_commit;
END;
/
-- Esperado: ORA-06519 (transação autônoma ativa detectada e revertida)

-- Esperado: 0
SELECT COUNT(*) FROM tmp_dados WHERE id = 4;

-- 6. Deadlock consigo mesmo: a autônoma tenta alterar a linha que o chamador travou.
INSERT INTO tmp_dados VALUES (5, 'original');
COMMIT;

CREATE OR REPLACE PROCEDURE tmp_proc_altera_5 IS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    UPDATE tmp_dados SET descricao = 'pela autônoma' WHERE id = 5;
    COMMIT;
END tmp_proc_altera_5;
/

BEGIN
    UPDATE tmp_dados SET descricao = 'pelo chamador' WHERE id = 5;
    tmp_proc_altera_5;
END;
/
-- Esperado (depois de alguns segundos): ORA-00060 (detectado impasse enquanto aguardava recurso)
--           O chamador espera a autônoma terminar; a autônoma espera a trava do chamador.

ROLLBACK;

-- Esperado: original
SELECT descricao FROM tmp_dados WHERE id = 5;

-- 7. O abuso: function com DML "funcionando" dentro de SELECT.
CREATE OR REPLACE FUNCTION tmp_fn_registra_consulta (p_id NUMBER) RETURN NUMBER IS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO tmp_log_erro (rotina, codigo, mensagem) VALUES ('consulta', p_id, 'leu o pedido');
    COMMIT;
    RETURN p_id;
END tmp_fn_registra_consulta;
/

-- Sem ORA-14551, mas: um INSERT e um COMMIT por linha lida, gravados mesmo que a
-- consulta seja interrompida no meio. Funciona; quase nunca é o que se quer.
SELECT tmp_fn_registra_consulta(id_pedido) FROM pedidos WHERE id_cliente = 1;

-- Esperado: 4
SELECT COUNT(*) FROM tmp_log_erro WHERE rotina = 'consulta';

DROP FUNCTION tmp_fn_registra_consulta;
DROP PROCEDURE tmp_proc_altera_5;
DROP PROCEDURE tmp_proc_esqueceu_commit;
DROP FUNCTION tmp_fn_conta_dados_autonoma;
DROP PROCEDURE tmp_registrar_erro;
DROP TABLE tmp_dados PURGE;
DROP TABLE tmp_log_erro PURGE;
