-- =============================================================================
-- Projeto : 01 — Controle de estoque — remoção
-- Seção   : 16-mini-projetos
-- Versão  : 19c
--
-- Remove os objetos do projeto, se existirem. Pode ser executado várias vezes.
-- =============================================================================

DECLARE
    TYPE t_lista IS TABLE OF VARCHAR2(200);

    -- Ordem: views e package, depois tabelas filhas antes das mães.
    v_comandos t_lista := t_lista(
        'DROP VIEW est_vw_abaixo_minimo',
        'DROP VIEW est_vw_kardex',
        'DROP PACKAGE est_pkg_estoque',
        'DROP TABLE est_movimentos CASCADE CONSTRAINTS PURGE',
        'DROP TABLE est_saldos CASCADE CONSTRAINTS PURGE',
        'DROP TABLE est_produtos CASCADE CONSTRAINTS PURGE',
        'DROP TABLE est_depositos CASCADE CONSTRAINTS PURGE',
        'DROP SEQUENCE est_seq_transferencia'
    );

    e_tabela_inexistente  EXCEPTION;
    e_objeto_inexistente  EXCEPTION;
    e_seq_inexistente     EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_tabela_inexistente, -942);
    PRAGMA EXCEPTION_INIT(e_objeto_inexistente, -4043);
    PRAGMA EXCEPTION_INIT(e_seq_inexistente, -2289);
BEGIN
    FOR i IN 1 .. v_comandos.COUNT LOOP
        BEGIN
            EXECUTE IMMEDIATE v_comandos(i);
            DBMS_OUTPUT.PUT_LINE('Executado: ' || v_comandos(i));
        EXCEPTION
            WHEN e_tabela_inexistente OR e_objeto_inexistente OR e_seq_inexistente THEN
                DBMS_OUTPUT.PUT_LINE('Ausente  : ' || v_comandos(i));
        END;
    END LOOP;
END;
/
