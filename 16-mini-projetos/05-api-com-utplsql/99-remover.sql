-- =============================================================================
-- Projeto : 05 — API em PL/SQL com utPLSQL — remoção
-- Seção   : 16-mini-projetos
-- Versão  : 19c
--
-- Remove os objetos do projeto, se existirem. Pode ser executado várias vezes.
-- =============================================================================

DECLARE
    TYPE t_lista IS TABLE OF VARCHAR2(200);

    -- Ordem: suite de testes, package, tabela.
    v_comandos t_lista := t_lista(
        'DROP PACKAGE test_api_pkg_clientes',
        'DROP PACKAGE api_pkg_clientes',
        'DROP TABLE api_clientes CASCADE CONSTRAINTS PURGE'
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
