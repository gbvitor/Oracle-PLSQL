-- =============================================================================
-- Tópico : Variáveis, constantes, %TYPE, %ROWTYPE, SUBTYPE
-- Seção  : 08-plsql-fundamentos
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- 1. Valores iniciais: sem inicialização, tudo começa NULL.
DECLARE
    v_sem_valor  NUMBER;
    v_com_valor  NUMBER := 10;
    v_default    NUMBER DEFAULT 20;
BEGIN
    DBMS_OUTPUT.PUT_LINE('sem valor + 1 = [' || (v_sem_valor + 1) || ']');
    DBMS_OUTPUT.PUT_LINE('com valor + 1 = [' || (v_com_valor + 1) || ']');
    DBMS_OUTPUT.PUT_LINE('default   + 1 = [' || (v_default + 1) || ']');
END;
/
-- Esperado:
--   sem valor + 1 = []
--   com valor + 1 = [11]
--   default   + 1 = [21]

-- 2. Constante não pode ser alterada.
DECLARE
    c_taxa CONSTANT NUMBER := 0.05;
BEGIN
    c_taxa := 0.10;
END;
/
-- Esperado: PLS-00363 (a expressão 'C_TAXA' não pode ser usada como destino de atribuição)

-- 3. %TYPE e %ROWTYPE.
DECLARE
    v_nome     clientes.nome%TYPE;
    v_uf       clientes.uf%TYPE;
    v_cliente  clientes%ROWTYPE;
BEGIN
    SELECT nome, uf INTO v_nome, v_uf FROM clientes WHERE id_cliente = 3;
    DBMS_OUTPUT.PUT_LINE('Com %TYPE:    ' || v_nome || ' / ' || v_uf);

    SELECT * INTO v_cliente FROM clientes WHERE id_cliente = 3;
    DBMS_OUTPUT.PUT_LINE('Com %ROWTYPE: ' || v_cliente.nome || ' / ' || v_cliente.cidade
                         || ' / limite ' || v_cliente.limite_credito);
END;
/
-- Esperado:
--   Com %TYPE:    Escritorio Modelo SA / MG
--   Com %ROWTYPE: Escritorio Modelo SA / Belo Horizonte / limite 80000

-- 4. Variável menor que o dado: ORA-06502 só com certos valores.
DECLARE
    v_nome VARCHAR2(20);
BEGIN
    FOR r IN (SELECT nome FROM clientes ORDER BY id_cliente) LOOP
        v_nome := r.nome;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('ok');
END;
/
-- Esperado: ORA-06502 (buffer de string de caracteres pequeno demais),
--           no primeiro nome com mais de 20 caracteres ("Papelaria Central Ltda", 22)

-- Com %TYPE, o tamanho acompanha a coluna.
DECLARE
    v_nome clientes.nome%TYPE;
BEGIN
    FOR r IN (SELECT nome FROM clientes ORDER BY id_cliente) LOOP
        v_nome := r.nome;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('ok: ultimo nome lido = ' || v_nome);
END;
/
-- Esperado: ok: ultimo nome lido = Thiago Nunes

-- 5. PLS_INTEGER estoura; SIMPLE_INTEGER dá a volta.
DECLARE
    v_pls PLS_INTEGER := 2147483647;
BEGIN
    v_pls := v_pls + 1;
END;
/
-- Esperado: ORA-01426 (overflow numérico)

DECLARE
    v_simples SIMPLE_INTEGER := 2147483647;
BEGIN
    v_simples := v_simples + 1;
    DBMS_OUTPUT.PUT_LINE('SIMPLE_INTEGER depois de +1: ' || v_simples);
END;
/
-- Esperado: SIMPLE_INTEGER depois de +1: -2147483648

-- 6. Texto não numérico atribuído a NUMBER.
DECLARE
    v_numero NUMBER;
BEGIN
    v_numero := 'abc';
END;
/
-- Esperado: ORA-06502 (erro de conversão de caractere em número)

-- 7. SUBTYPE e constantes para dar nome às regras.
DECLARE
    SUBTYPE t_valor IS NUMBER(12,2);
    c_desconto_maximo CONSTANT NUMBER := 10;
    v_bruto   t_valor;
    v_liquido t_valor;
BEGIN
    SELECT SUM(quantidade * preco_unitario) INTO v_bruto FROM itens_pedido WHERE id_pedido = 1008;
    v_liquido := v_bruto * (1 - c_desconto_maximo / 100);
    DBMS_OUTPUT.PUT_LINE('Bruto ' || v_bruto || ' | com ' || c_desconto_maximo || '% = ' || v_liquido);
END;
/
-- Esperado: Bruto 30757 | com 10% = 27681.3

-- 8. BOOLEAN: três estados.
DECLARE
    v_flag BOOLEAN;
BEGIN
    DBMS_OUTPUT.PUT_LINE(CASE WHEN v_flag THEN 'TRUE' WHEN NOT v_flag THEN 'FALSE' ELSE 'NULL' END);
    v_flag := (1 = 1);
    DBMS_OUTPUT.PUT_LINE(CASE WHEN v_flag THEN 'TRUE' WHEN NOT v_flag THEN 'FALSE' ELSE 'NULL' END);
END;
/
-- Esperado:
--   NULL
--   TRUE
