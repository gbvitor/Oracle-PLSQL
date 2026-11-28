-- =============================================================================
-- Projeto : 02 — Biblioteca — remoção
-- Seção   : 16-mini-projetos
-- Versão  : 19c
--
-- Remove os objetos do projeto, se existirem. Pode ser executado várias vezes.
-- =============================================================================

DECLARE
    TYPE t_lista IS TABLE OF VARCHAR2(200);

    -- Ordem: views e package, depois tabelas filhas antes das mães.
    v_comandos t_lista := t_lista(
        'DROP VIEW bib_vw_fila_reservas',
        'DROP VIEW bib_vw_atrasos',
        'DROP PACKAGE bib_pkg_biblioteca',
        'DROP TABLE bib_reservas CASCADE CONSTRAINTS PURGE',
        'DROP TABLE bib_emprestimos CASCADE CONSTRAINTS PURGE',
        'DROP TABLE bib_exemplares CASCADE CONSTRAINTS PURGE',
        'DROP TABLE bib_obras CASCADE CONSTRAINTS PURGE',
        'DROP TABLE bib_leitores CASCADE CONSTRAINTS PURGE',
        'DROP TABLE bib_categorias_leitor CASCADE CONSTRAINTS PURGE'
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
