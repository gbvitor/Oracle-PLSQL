-- =============================================================================
-- Projeto : 04 — Log e auditoria genéricos — package LOG_PKG_AUDITORIA
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : 01-tabelas.sql, 02-pacote-log.sql; CREATE PROCEDURE e
--           CREATE TRIGGER concedido DIRETAMENTE ao usuário (não por role):
--           privilégio de role não vale dentro de package com AUTHID DEFINER.
--
-- Gera, a partir do dicionário de dados, o trigger de auditoria de qualquer
-- tabela do schema que tenha chave primária.
-- =============================================================================

CREATE OR REPLACE PACKAGE log_pkg_auditoria AS

    e_tabela_invalida EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_tabela_invalida, -20402);

    -- Chamado pelo trigger gerado. Grava só se o valor mudou (NULL = NULL).
    PROCEDURE registrar (
        p_tabela   IN VARCHAR2,
        p_chave    IN VARCHAR2,
        p_operacao IN VARCHAR2,
        p_coluna   IN VARCHAR2,
        p_antigo   IN VARCHAR2,
        p_novo     IN VARCHAR2
    );

    -- Texto do trigger para a tabela, sem criar (para revisar antes).
    FUNCTION texto_trigger (p_tabela IN VARCHAR2) RETURN CLOB;

    -- Cria (ou recria) o trigger LOG_AUD_<tabela>. A tabela mudou de colunas? Gere de novo.
    PROCEDURE gerar_trigger (p_tabela IN VARCHAR2);

    PROCEDURE remover_trigger (p_tabela IN VARCHAR2);

END log_pkg_auditoria;
/

CREATE OR REPLACE PACKAGE BODY log_pkg_auditoria AS

    c_nl CONSTANT VARCHAR2(1) := CHR(10);

    PROCEDURE registrar (
        p_tabela   IN VARCHAR2,
        p_chave    IN VARCHAR2,
        p_operacao IN VARCHAR2,
        p_coluna   IN VARCHAR2,
        p_antigo   IN VARCHAR2,
        p_novo     IN VARCHAR2
    ) IS
    BEGIN
        -- Sem PRAGMA AUTONOMOUS_TRANSACTION, de propósito: auditoria de alteração
        -- desfeita não deve existir.
        IF DECODE(p_antigo, p_novo, 0, 1) = 1 THEN
            INSERT INTO log_aud_alteracoes (id_execucao, tabela, chave, operacao, coluna, valor_antigo, valor_novo)
            VALUES (log_pkg.execucao_atual, p_tabela, SUBSTR(p_chave, 1, 400), p_operacao, p_coluna,
                    p_antigo, p_novo);
        END IF;
    END registrar;

    -- Valida o nome contra injeção (DBMS_ASSERT) e contra o dicionário.
    FUNCTION tabela_validada (p_tabela IN VARCHAR2) RETURN VARCHAR2 IS
        v_tabela VARCHAR2(128);
        v_existe PLS_INTEGER;
    BEGIN
        BEGIN
            v_tabela := UPPER(DBMS_ASSERT.SIMPLE_SQL_NAME(p_tabela));
        EXCEPTION
            WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(-20402, 'Nome de tabela inválido: ' || SUBSTR(p_tabela, 1, 100));
        END;

        SELECT COUNT(*) INTO v_existe FROM user_tables WHERE table_name = v_tabela;
        IF v_existe = 0 THEN
            RAISE_APPLICATION_ERROR(-20402, 'Tabela não encontrada no schema: ' || v_tabela);
        END IF;

        RETURN v_tabela;
    END tabela_validada;

    -- Expressão que converte a coluna em texto, igual em qualquer sessão
    -- (número com ponto decimal, data em ISO).
    FUNCTION como_texto (p_ref IN VARCHAR2, p_coluna IN VARCHAR2, p_tipo IN VARCHAR2) RETURN VARCHAR2 IS
        v_col VARCHAR2(200) := ':' || p_ref || '.' || p_coluna;
    BEGIN
        RETURN CASE
                   WHEN p_tipo IN ('NUMBER', 'FLOAT', 'BINARY_FLOAT', 'BINARY_DOUBLE')
                       THEN 'TO_CHAR(' || v_col || q'[, 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')]'
                   WHEN p_tipo = 'DATE'
                       THEN 'TO_CHAR(' || v_col || q'[, 'YYYY-MM-DD HH24:MI:SS')]'
                   WHEN p_tipo LIKE 'TIMESTAMP%'
                       THEN 'TO_CHAR(' || v_col || q'[, 'YYYY-MM-DD HH24:MI:SS.FF6')]'
                   ELSE 'SUBSTR(' || v_col || ', 1, 4000)'
               END;
    END como_texto;

    FUNCTION texto_trigger (p_tabela IN VARCHAR2) RETURN CLOB IS
        v_tabela    VARCHAR2(128) := tabela_validada(p_tabela);
        v_chave_old VARCHAR2(4000);
        v_chave_new VARCHAR2(4000);
        v_colunas   CLOB;
        v_qtd_pk    PLS_INTEGER := 0;
        v_qtd_col   PLS_INTEGER := 0;
    BEGIN
        -- Chave primária: colunas na ordem da constraint, separadas por '|'.
        FOR r IN (SELECT cc.column_name, tc.data_type
                    FROM user_constraints c
                    JOIN user_cons_columns cc
                      ON cc.constraint_name = c.constraint_name AND cc.table_name = c.table_name
                    JOIN user_tab_columns tc
                      ON tc.table_name = cc.table_name AND tc.column_name = cc.column_name
                   WHERE c.table_name = v_tabela
                     AND c.constraint_type = 'P'
                   ORDER BY cc.position)
        LOOP
            v_qtd_pk := v_qtd_pk + 1;
            IF v_qtd_pk > 1 THEN
                v_chave_old := v_chave_old || q'[ || '|' || ]';
                v_chave_new := v_chave_new || q'[ || '|' || ]';
            END IF;
            v_chave_old := v_chave_old || como_texto('OLD', r.column_name, r.data_type);
            v_chave_new := v_chave_new || como_texto('NEW', r.column_name, r.data_type);
        END LOOP;

        IF v_qtd_pk = 0 THEN
            RAISE_APPLICATION_ERROR(-20402, 'Tabela ' || v_tabela || ' sem chave primária');
        END IF;

        -- Demais colunas de tipos escalares; LOB, LONG, RAW e tipos de objeto ficam de fora.
        FOR r IN (SELECT tc.column_name, tc.data_type
                    FROM user_tab_columns tc
                   WHERE tc.table_name = v_tabela
                     AND (tc.data_type IN ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR', 'NUMBER', 'FLOAT',
                                           'BINARY_FLOAT', 'BINARY_DOUBLE', 'DATE')
                          OR tc.data_type LIKE 'TIMESTAMP%')
                     AND tc.column_name NOT IN (SELECT cc.column_name
                                                  FROM user_constraints c
                                                  JOIN user_cons_columns cc
                                                    ON cc.constraint_name = c.constraint_name
                                                   AND cc.table_name = c.table_name
                                                 WHERE c.table_name = v_tabela
                                                   AND c.constraint_type = 'P')
                   ORDER BY tc.column_id)
        LOOP
            v_qtd_col := v_qtd_col + 1;
            v_colunas := v_colunas
                || '    log_pkg_auditoria.registrar(''' || v_tabela || ''', v_chave, v_op, '''
                || r.column_name || ''',' || c_nl
                || '        ' || como_texto('OLD', r.column_name, r.data_type) || ',' || c_nl
                || '        ' || como_texto('NEW', r.column_name, r.data_type) || ');' || c_nl;
        END LOOP;

        IF v_qtd_col = 0 THEN
            RAISE_APPLICATION_ERROR(-20402, 'Tabela ' || v_tabela || ' sem colunas auditáveis além da chave');
        END IF;

        RETURN 'CREATE OR REPLACE TRIGGER ' || SUBSTR('LOG_AUD_' || v_tabela, 1, 128) || c_nl
            || 'AFTER INSERT OR UPDATE OR DELETE ON ' || v_tabela || c_nl
            || 'FOR EACH ROW' || c_nl
            || '-- Gerado por log_pkg_auditoria.gerar_trigger. Não editar: gerar de novo.' || c_nl
            || 'DECLARE' || c_nl
            || '    v_op    CHAR(1);' || c_nl
            || '    v_chave VARCHAR2(4000);' || c_nl
            || 'BEGIN' || c_nl
            || q'[    IF INSERTING THEN v_op := 'I'; ELSIF UPDATING THEN v_op := 'U'; ELSE v_op := 'D'; END IF;]' || c_nl
            || '    IF DELETING THEN' || c_nl
            || '        v_chave := ' || v_chave_old || ';' || c_nl
            || '    ELSE' || c_nl
            || '        v_chave := ' || v_chave_new || ';' || c_nl
            || '    END IF;' || c_nl
            || v_colunas
            || 'END;';
    END texto_trigger;

    -- DDL faz COMMIT implícito. Em transação autônoma, o COMMIT é só dela:
    -- o trabalho pendente de quem chamou não é confirmado sem querer.
    PROCEDURE gerar_trigger (p_tabela IN VARCHAR2) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        EXECUTE IMMEDIATE texto_trigger(p_tabela);
        log_pkg.info('Trigger de auditoria gerado para ' || UPPER(p_tabela));
    END gerar_trigger;

    PROCEDURE remover_trigger (p_tabela IN VARCHAR2) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        v_tabela VARCHAR2(128) := tabela_validada(p_tabela);
    BEGIN
        EXECUTE IMMEDIATE 'DROP TRIGGER ' || SUBSTR('LOG_AUD_' || v_tabela, 1, 128);
        log_pkg.info('Trigger de auditoria removido de ' || v_tabela);
    END remover_trigger;

END log_pkg_auditoria;
/

SHOW ERRORS PACKAGE BODY log_pkg_auditoria
