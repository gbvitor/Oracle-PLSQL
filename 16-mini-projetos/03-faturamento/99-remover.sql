-- =============================================================================
-- Projeto : 03 — Faturamento simplificado — remoção
-- Seção   : 16-mini-projetos
-- Versão  : 19c
--
-- Remove os objetos do projeto, se existirem. Pode ser executado várias vezes.
-- =============================================================================

DECLARE
    TYPE t_lista IS TABLE OF VARCHAR2(200);

    -- Ordem: views e package, depois tabelas filhas antes das mães.
    v_comandos t_lista := t_lista(
        'DROP VIEW fat_vw_titulos_abertos',
        'DROP VIEW fat_vw_posicao_cliente',
        'DROP PACKAGE fat_pkg_faturamento',
        'DROP TABLE fat_baixas CASCADE CONSTRAINTS PURGE',
        'DROP TABLE fat_titulos CASCADE CONSTRAINTS PURGE',
        'DROP TABLE fat_itens_nota CASCADE CONSTRAINTS PURGE',
        'DROP TABLE fat_notas CASCADE CONSTRAINTS PURGE',
        'DROP TABLE fat_itens_pedido CASCADE CONSTRAINTS PURGE',
        'DROP TABLE fat_pedidos CASCADE CONSTRAINTS PURGE',
        'DROP TABLE fat_condicoes_parcelas CASCADE CONSTRAINTS PURGE',
        'DROP TABLE fat_condicoes CASCADE CONSTRAINTS PURGE',
        'DROP TABLE fat_produtos CASCADE CONSTRAINTS PURGE',
        'DROP TABLE fat_clientes CASCADE CONSTRAINTS PURGE',
        'DROP TABLE fat_numeracao CASCADE CONSTRAINTS PURGE'
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
