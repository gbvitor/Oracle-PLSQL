-- =============================================================================
-- Caso   : Processamento em lote — BULK COLLECT por bloco, FORALL SAVE EXCEPTIONS,
--          commit por bloco, situação por linha, retomada e log autônomo
-- Seção  : 15-casos-de-uso
-- Versão : 19c
-- Requer : CREATE TABLE, CREATE PROCEDURE, CREATE TRIGGER (não usa o schema de exemplo)
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- 1. Entrada, destino e log.
-- 10.000 linhas; as de id múltiplo de 2500 têm valor -1 e vão violar o CHECK do destino.
CREATE TABLE tmp_lote_entrada (
    id        NUMBER        CONSTRAINT pk_tmp_lote_entrada PRIMARY KEY,
    valor     NUMBER        NOT NULL,
    situacao  CHAR(1)       DEFAULT 'N' NOT NULL
              CONSTRAINT ck_tmp_lote_entrada_sit CHECK (situacao IN ('N', 'S', 'E')),
    erro      VARCHAR2(400)
);

INSERT INTO tmp_lote_entrada (id, valor)
SELECT LEVEL,
       CASE WHEN MOD(LEVEL, 2500) = 0 THEN -1 ELSE MOD(LEVEL, 100) + 1 END
  FROM dual
CONNECT BY LEVEL <= 10000;
COMMIT;

CREATE TABLE tmp_lote_destino (
    id          NUMBER  CONSTRAINT pk_tmp_lote_destino PRIMARY KEY,
    valor       NUMBER  NOT NULL CONSTRAINT ck_tmp_lote_destino_valor CHECK (valor > 0),
    data_carga  DATE    NOT NULL
);

CREATE TABLE tmp_lote_log (
    id_log     NUMBER GENERATED ALWAYS AS IDENTITY CONSTRAINT pk_tmp_lote_log PRIMARY KEY,
    execucao   NUMBER        NOT NULL,
    bloco      NUMBER,
    lidas      NUMBER,
    gravadas   NUMBER,
    com_erro   NUMBER,
    mensagem   VARCHAR2(4000),
    momento    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL
);

-- 2. Log em transação autônoma: sobrevive ao ROLLBACK de quem chamou.
CREATE OR REPLACE PROCEDURE tmp_prc_lote_log (
    p_execucao IN NUMBER,
    p_bloco    IN NUMBER,
    p_lidas    IN NUMBER,
    p_gravadas IN NUMBER,
    p_com_erro IN NUMBER,
    p_mensagem IN VARCHAR2 DEFAULT NULL
) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO tmp_lote_log (execucao, bloco, lidas, gravadas, com_erro, mensagem)
    VALUES (p_execucao, p_bloco, p_lidas, p_gravadas, p_com_erro, SUBSTR(p_mensagem, 1, 4000));
    COMMIT;
END tmp_prc_lote_log;
/

-- 3. O processamento.
--    p_max_blocos simula uma queda: para depois de N blocos.
CREATE OR REPLACE PROCEDURE tmp_prc_processar_lote (
    p_limite     IN PLS_INTEGER DEFAULT 1000,
    p_max_blocos IN PLS_INTEGER DEFAULT NULL
) IS
    TYPE t_numeros IS TABLE OF NUMBER;
    TYPE t_situacao IS TABLE OF CHAR(1) INDEX BY PLS_INTEGER;
    TYPE t_mensagem IS TABLE OF VARCHAR2(400) INDEX BY PLS_INTEGER;

    e_erros_forall EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_erros_forall, -24381);

    v_ids       t_numeros;
    v_valores   t_numeros;
    v_situacao  t_situacao;
    v_mensagem  t_mensagem;
    v_execucao  NUMBER;
    v_bloco     PLS_INTEGER := 0;
    v_erros     PLS_INTEGER;
    v_idx       PLS_INTEGER;
    v_total_ok  PLS_INTEGER := 0;
    v_total_err PLS_INTEGER := 0;
BEGIN
    -- Número da execução (supõe uma execução por vez).
    SELECT NVL(MAX(execucao), 0) + 1 INTO v_execucao FROM tmp_lote_log;

    LOOP
        EXIT WHEN p_max_blocos IS NOT NULL AND v_bloco >= p_max_blocos;

        SELECT id, valor
          BULK COLLECT INTO v_ids, v_valores
          FROM tmp_lote_entrada
         WHERE situacao = 'N'
         ORDER BY id
         FETCH FIRST p_limite ROWS ONLY;

        EXIT WHEN v_ids.COUNT = 0;
        v_bloco := v_bloco + 1;

        v_situacao.DELETE;
        v_mensagem.DELETE;
        FOR i IN 1 .. v_ids.COUNT LOOP
            v_situacao(i) := 'S';
            v_mensagem(i) := NULL;
        END LOOP;

        v_erros := 0;
        BEGIN
            FORALL i IN 1 .. v_ids.COUNT SAVE EXCEPTIONS
                INSERT INTO tmp_lote_destino (id, valor, data_carga)
                VALUES (v_ids(i), v_valores(i), SYSDATE);
        EXCEPTION
            WHEN e_erros_forall THEN
                v_erros := SQL%BULK_EXCEPTIONS.COUNT;
                FOR j IN 1 .. v_erros LOOP
                    v_idx := SQL%BULK_EXCEPTIONS(j).ERROR_INDEX;
                    v_situacao(v_idx) := 'E';
                    v_mensagem(v_idx) := SQLERRM(-SQL%BULK_EXCEPTIONS(j).ERROR_CODE);
                END LOOP;
        END;

        -- Marca o bloco na mesma transação da gravação no destino.
        FORALL i IN 1 .. v_ids.COUNT
            UPDATE tmp_lote_entrada
               SET situacao = v_situacao(i),
                   erro     = v_mensagem(i)
             WHERE id = v_ids(i);

        COMMIT;

        v_total_ok  := v_total_ok + (v_ids.COUNT - v_erros);
        v_total_err := v_total_err + v_erros;
        tmp_prc_lote_log(v_execucao, v_bloco, v_ids.COUNT, v_ids.COUNT - v_erros, v_erros);
    END LOOP;

    tmp_prc_lote_log(v_execucao, NULL, NULL, v_total_ok, v_total_err,
                     'Fim: ' || v_bloco || ' bloco(s)');
    DBMS_OUTPUT.PUT_LINE('Execução ' || v_execucao || ': ' || v_bloco || ' bloco(s), '
                         || v_total_ok || ' gravada(s), ' || v_total_err || ' com erro');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        tmp_prc_lote_log(v_execucao, v_bloco, NULL, NULL, NULL,
                         'Falha: ' || DBMS_UTILITY.FORMAT_ERROR_STACK
                         || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        RAISE;
END tmp_prc_processar_lote;
/

SHOW ERRORS PROCEDURE tmp_prc_processar_lote

-- 4. Primeira execução, "cai" depois de 3 blocos.
EXEC tmp_prc_processar_lote(p_max_blocos => 3)
-- Esperado: Execução 1: 3 bloco(s), 2999 gravada(s), 1 com erro   (id 2500)

-- Esperado: E 1 | N 7000 | S 2999
SELECT situacao, COUNT(*) FROM tmp_lote_entrada GROUP BY situacao ORDER BY situacao;

-- 5. Retomada: continua do id 3001.
EXEC tmp_prc_processar_lote
-- Esperado: Execução 2: 7 bloco(s), 6997 gravada(s), 3 com erro   (ids 5000, 7500, 10000)

-- Esperado: E 4 | S 9996
SELECT situacao, COUNT(*) FROM tmp_lote_entrada GROUP BY situacao ORDER BY situacao;

-- Esperado: 9996
SELECT COUNT(*) FROM tmp_lote_destino;

-- As linhas com erro e o motivo.
-- Esperado: 2500, 5000, 7500, 10000, todas com ORA-02290 (restrição CHECK violada);
--           SQLERRM pelo código não traz o nome da constraint
SELECT id, valor, erro FROM tmp_lote_entrada WHERE situacao = 'E' ORDER BY id;

-- 6. Rodar de novo sem pendentes: nada acontece.
EXEC tmp_prc_processar_lote
-- Esperado: Execução 3: 0 bloco(s), 0 gravada(s), 0 com erro

-- 7. Corrigir os erros e reprocessar só eles.
UPDATE tmp_lote_entrada
   SET valor = 1, situacao = 'N', erro = NULL
 WHERE situacao = 'E';
COMMIT;

EXEC tmp_prc_processar_lote
-- Esperado: Execução 4: 1 bloco(s), 4 gravada(s), 0 com erro

-- Esperado: 10000
SELECT COUNT(*) FROM tmp_lote_destino;

-- 8. O log das execuções.
-- Esperado: execução 1 com blocos 1 a 3 (o 3º com 1 erro) e a linha de fim;
--           execução 2 com blocos 1 a 7 (erros nos blocos 2, 5 e 7) e a linha de fim;
--           execução 3 só com a linha de fim; execução 4 com bloco 1 e a linha de fim
SELECT execucao, bloco, lidas, gravadas, com_erro, mensagem
  FROM tmp_lote_log
 ORDER BY id_log;

-- 9. Falha que não é de linha: o bloco é desfeito e o log autônomo fica.
--    Simulação: um trigger de comando que impede marcar a entrada.
DELETE FROM tmp_lote_destino WHERE id <= 10;
UPDATE tmp_lote_entrada SET situacao = 'N' WHERE id <= 10;
COMMIT;

CREATE OR REPLACE TRIGGER tmp_trg_lote_falha
BEFORE UPDATE ON tmp_lote_entrada
BEGIN
    RAISE_APPLICATION_ERROR(-20099, 'Falha simulada');
END;
/

-- Esperado: ORA-20099: Falha simulada (e as linhas ORA-06512 de onde passou)
EXEC tmp_prc_processar_lote

-- O INSERT no destino daquele bloco foi desfeito pelo ROLLBACK.
-- Esperado: 9990 | 10
SELECT (SELECT COUNT(*) FROM tmp_lote_destino) AS destino,
       (SELECT COUNT(*) FROM tmp_lote_entrada WHERE situacao = 'N') AS pendentes
  FROM dual;

-- O log da falha ficou (transação autônoma).
-- Esperado: 5 | 1 | Falha: ORA-20099: Falha simulada ... (com o backtrace)
SELECT execucao, bloco, SUBSTR(mensagem, 1, 60) AS mensagem
  FROM tmp_lote_log
 WHERE execucao = (SELECT MAX(execucao) FROM tmp_lote_log);

-- Removida a causa, a retomada termina o trabalho.
DROP TRIGGER tmp_trg_lote_falha;

EXEC tmp_prc_processar_lote
-- Esperado: Execução 6: 1 bloco(s), 10 gravada(s), 0 com erro

-- Limpeza.
DROP PROCEDURE tmp_prc_processar_lote;
DROP PROCEDURE tmp_prc_lote_log;
DROP TABLE tmp_lote_destino PURGE;
DROP TABLE tmp_lote_log PURGE;
DROP TABLE tmp_lote_entrada PURGE;
