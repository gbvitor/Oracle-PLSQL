-- =============================================================================
-- Projeto : 04 — Log e auditoria genéricos — package LOG_PKG
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : 01-tabelas.sql; CREATE PROCEDURE
--
-- Log reutilizável por qualquer processo: níveis, execução com início e fim,
-- erro com pilha e backtrace, gravação autônoma e expurgo.
-- =============================================================================

CREATE OR REPLACE PACKAGE log_pkg AS

    e_nivel_invalido EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_nivel_invalido, -20401);

    -- Nível mínimo gravado nesta sessão: DEBUG, INFO (padrão), AVISO ou ERRO.
    PROCEDURE definir_nivel (p_nivel IN VARCHAR2);
    FUNCTION  nivel_atual RETURN VARCHAR2;

    -- Abre uma execução, marca a sessão com o módulo (V$SESSION.MODULE)
    -- e devolve o id que agrupa os eventos dela.
    FUNCTION  iniciar_execucao (p_modulo IN VARCHAR2) RETURN NUMBER;
    PROCEDURE finalizar_execucao (p_situacao IN VARCHAR2 DEFAULT 'OK');
    FUNCTION  execucao_atual RETURN NUMBER;

    PROCEDURE debug (p_mensagem IN VARCHAR2);
    PROCEDURE info  (p_mensagem IN VARCHAR2);
    PROCEDURE aviso (p_mensagem IN VARCHAR2);

    -- Chamar dentro do handler: grava a pilha do erro, o backtrace (linha onde
    -- o erro nasceu) e a pilha de chamadas. Sem mensagem, usa a primeira linha do erro.
    PROCEDURE erro  (p_mensagem IN VARCHAR2 DEFAULT NULL);

    -- Apaga eventos com mais de p_dias dias. Devolve quantos apagou.
    FUNCTION  expurgar (p_dias IN PLS_INTEGER) RETURN PLS_INTEGER;

END log_pkg;
/

CREATE OR REPLACE PACKAGE BODY log_pkg AS

    -- Estado da sessão: cada sessão tem a sua cópia das variáveis da package.
    g_nivel_minimo  PLS_INTEGER := 2;
    g_id_execucao   NUMBER;
    g_modulo        VARCHAR2(64);

    FUNCTION peso (p_nivel IN VARCHAR2) RETURN PLS_INTEGER IS
    BEGIN
        RETURN CASE UPPER(p_nivel)
                   WHEN 'DEBUG' THEN 1
                   WHEN 'INFO'  THEN 2
                   WHEN 'AVISO' THEN 3
                   WHEN 'ERRO'  THEN 4
               END;
    END peso;

    PROCEDURE definir_nivel (p_nivel IN VARCHAR2) IS
    BEGIN
        IF peso(p_nivel) IS NULL THEN
            RAISE_APPLICATION_ERROR(-20401,
                'Nível inválido: ' || NVL(p_nivel, 'nulo') || ' (use DEBUG, INFO, AVISO ou ERRO)');
        END IF;
        g_nivel_minimo := peso(p_nivel);
    END definir_nivel;

    FUNCTION nivel_atual RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE g_nivel_minimo WHEN 1 THEN 'DEBUG' WHEN 2 THEN 'INFO' WHEN 3 THEN 'AVISO' ELSE 'ERRO' END;
    END nivel_atual;

    FUNCTION execucao_atual RETURN NUMBER IS
    BEGIN
        RETURN g_id_execucao;
    END execucao_atual;

    -- Gravação em transação autônoma. Falha do log não derruba o processo que
    -- loga: o erro é mostrado no DBMS_OUTPUT e engolido. É uma decisão consciente
    -- (o log é acessório); o preço é que um log quebrado só aparece no output.
    PROCEDURE gravar (
        p_nivel    IN VARCHAR2,
        p_mensagem IN VARCHAR2,
        p_detalhe  IN CLOB DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        IF peso(p_nivel) < g_nivel_minimo THEN
            RETURN;
        END IF;

        INSERT INTO log_eventos (nivel, id_execucao, modulo, mensagem, detalhe, sid)
        VALUES (p_nivel, g_id_execucao,
                NVL(g_modulo, SYS_CONTEXT('USERENV', 'MODULE')),
                SUBSTR(NVL(p_mensagem, '(sem mensagem)'), 1, 4000),
                p_detalhe,
                SYS_CONTEXT('USERENV', 'SID'));
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('log_pkg: falha ao gravar o log: ' || SQLERRM);
    END gravar;

    FUNCTION iniciar_execucao (p_modulo IN VARCHAR2) RETURN NUMBER IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        g_modulo := SUBSTR(p_modulo, 1, 64);

        INSERT INTO log_execucoes (modulo, sid)
        VALUES (g_modulo, SYS_CONTEXT('USERENV', 'SID'))
        RETURNING id_execucao INTO g_id_execucao;
        COMMIT;

        -- MODULE aceita 48 bytes e ACTION 32; aparecem em V$SESSION e nos relatórios AWR/ASH.
        DBMS_APPLICATION_INFO.SET_MODULE(SUBSTR(g_modulo, 1, 48), 'execucao ' || g_id_execucao);
        RETURN g_id_execucao;
    END iniciar_execucao;

    PROCEDURE finalizar_execucao (p_situacao IN VARCHAR2 DEFAULT 'OK') IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        IF g_id_execucao IS NOT NULL THEN
            UPDATE log_execucoes
               SET fim = SYSTIMESTAMP,
                   situacao = CASE WHEN UPPER(p_situacao) = 'ERRO' THEN 'ERRO' ELSE 'OK' END
             WHERE id_execucao = g_id_execucao;
            COMMIT;
        END IF;
        g_id_execucao := NULL;
        g_modulo      := NULL;
        DBMS_APPLICATION_INFO.SET_MODULE(NULL, NULL);
    END finalizar_execucao;

    PROCEDURE debug (p_mensagem IN VARCHAR2) IS
    BEGIN
        gravar('DEBUG', p_mensagem);
    END debug;

    PROCEDURE info (p_mensagem IN VARCHAR2) IS
    BEGIN
        gravar('INFO', p_mensagem);
    END info;

    PROCEDURE aviso (p_mensagem IN VARCHAR2) IS
    BEGIN
        gravar('AVISO', p_mensagem);
    END aviso;

    PROCEDURE erro (p_mensagem IN VARCHAR2 DEFAULT NULL) IS
        v_pilha   VARCHAR2(4000);
        v_detalhe CLOB;
    BEGIN
        -- Lidos aqui, antes de qualquer outra chamada que possa trocar o erro corrente.
        v_pilha   := DBMS_UTILITY.FORMAT_ERROR_STACK;
        v_detalhe := v_pilha
                  || 'Backtrace:' || CHR(10) || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                  || 'Chamadas:'  || CHR(10) || DBMS_UTILITY.FORMAT_CALL_STACK;

        gravar('ERRO',
               NVL(p_mensagem, RTRIM(SUBSTR(v_pilha, 1, INSTR(v_pilha || CHR(10), CHR(10)) - 1))),
               v_detalhe);
    END erro;

    FUNCTION expurgar (p_dias IN PLS_INTEGER) RETURN PLS_INTEGER IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        v_qtd PLS_INTEGER;
    BEGIN
        DELETE FROM log_eventos
         WHERE momento < SYSTIMESTAMP - NUMTODSINTERVAL(p_dias, 'DAY');
        v_qtd := SQL%ROWCOUNT;
        COMMIT;
        RETURN v_qtd;
    END expurgar;

END log_pkg;
/

SHOW ERRORS PACKAGE BODY log_pkg
