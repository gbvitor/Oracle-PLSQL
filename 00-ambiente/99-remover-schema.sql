-- =============================================================================
-- Tópico : Schema de exemplo — remoção
-- Seção  : 00-ambiente
-- Versão : 19c
--
-- Remove as tabelas do schema de exemplo, se existirem. Pode ser executado
-- várias vezes sem erro.
--
-- Em 19c não existe DROP TABLE IF EXISTS; o bloco abaixo tenta o DROP e
-- ignora só o erro ORA-00942 (tabela inexistente). Qualquer outro erro sobe.
-- [23ai+] Equivalente direto: DROP TABLE IF EXISTS itens_pedido CASCADE CONSTRAINTS PURGE;
-- =============================================================================

DECLARE
    TYPE t_lista IS TABLE OF VARCHAR2(30);

    -- Ordem: filhas antes das mães.
    v_tabelas  t_lista := t_lista('itens_pedido', 'pedidos', 'produtos', 'categorias',
                                  'clientes', 'funcionarios', 'departamentos');

    e_tabela_inexistente EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_tabela_inexistente, -942);
BEGIN
    FOR i IN 1 .. v_tabelas.COUNT LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE ' || v_tabelas(i) || ' CASCADE CONSTRAINTS PURGE';
            DBMS_OUTPUT.PUT_LINE('Removida : ' || v_tabelas(i));
        EXCEPTION
            WHEN e_tabela_inexistente THEN
                DBMS_OUTPUT.PUT_LINE('Ausente  : ' || v_tabelas(i));
        END;
    END LOOP;
END;
/
