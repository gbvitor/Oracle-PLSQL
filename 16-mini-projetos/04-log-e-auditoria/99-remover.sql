-- =============================================================================
-- Projeto : 04 — Log e auditoria genéricos — remoção
-- Seção   : 16-mini-projetos
-- Versão  : 19c
--
-- Remove os objetos do projeto, se existirem. Pode ser executado várias vezes.
-- =============================================================================

DECLARE
    TYPE t_lista IS TABLE OF VARCHAR2(200);

    -- A tabela de demonstração leva junto o trigger gerado; depois packages e tabelas.
    v_comandos t_lista := t_lista(
        'DROP TABLE log_demo_contas CASCADE CONSTRAINTS PURGE',
        'DROP PACKAGE log_pkg_auditoria',
        'DROP PACKAGE log_pkg',
        'DROP TABLE log_aud_alteracoes CASCADE CONSTRAINTS PURGE',
        'DROP TABLE log_eventos CASCADE CONSTRAINTS PURGE',
        'DROP TABLE log_execucoes CASCADE CONSTRAINTS PURGE'
    );


    e_tabela_inexistente  EXCEPTION;
    e_objeto_inexistente  EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_tabela_inexistente, -942);
    PRAGMA EXCEPTION_INIT(e_objeto_inexistente, -4043);
BEGIN
    FOR i IN 1 .. v_comandos.COUNT LOOP
        BEGIN
            EXECUTE IMMEDIATE v_comandos(i);
            DBMS_OUTPUT.PUT_LINE('Executado: ' || v_comandos(i));
        EXCEPTION
            WHEN e_tabela_inexistente OR e_objeto_inexistente THEN
                DBMS_OUTPUT.PUT_LINE('Ausente  : ' || v_comandos(i));
        END;
    END LOOP;
END;
/
