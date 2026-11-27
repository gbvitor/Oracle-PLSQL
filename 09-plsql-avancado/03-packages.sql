-- =============================================================================
-- Tópico : Packages — especificação, corpo, privados, estado, inicialização,
--          overloading, exceção pública e ORA-04068
-- Seção  : 09-plsql-avancado
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); CREATE PROCEDURE
--          Passo 7 usa duas sessões conectadas como o mesmo usuário.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- 1. Especificação: o contrato público.
CREATE OR REPLACE PACKAGE tmp_pkg_vendas IS
    c_status_cancelado CONSTANT pedidos.status%TYPE := 'CANCELADO';

    e_limite_excedido EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_limite_excedido, -20101);

    FUNCTION valor_pedido (p_id_pedido IN pedidos.id_pedido%TYPE) RETURN NUMBER;

    FUNCTION valor_cliente (p_id_cliente IN clientes.id_cliente%TYPE) RETURN NUMBER;

    PROCEDURE validar_credito (
        p_id_cliente IN clientes.id_cliente%TYPE,
        p_valor_novo IN NUMBER
    );

    FUNCTION formatar (p_valor IN NUMBER) RETURN VARCHAR2;
    FUNCTION formatar (p_data  IN DATE)   RETURN VARCHAR2;

    FUNCTION chamadas RETURN PLS_INTEGER;
END tmp_pkg_vendas;
/

-- 2. Corpo: implementação, itens privados e inicialização.
CREATE OR REPLACE PACKAGE BODY tmp_pkg_vendas IS

    -- Privado: estado da sessão.
    g_chamadas PLS_INTEGER := 0;

    -- Privado: rotina que só o corpo enxerga.
    FUNCTION total_itens (p_id_pedido IN NUMBER) RETURN NUMBER IS
        v_total NUMBER;
    BEGIN
        SELECT SUM(ROUND(quantidade * preco_unitario * (1 - pct_desconto / 100), 2))
          INTO v_total
          FROM itens_pedido
         WHERE id_pedido = p_id_pedido;
        RETURN v_total;
    END total_itens;

    FUNCTION valor_pedido (p_id_pedido IN pedidos.id_pedido%TYPE) RETURN NUMBER IS
    BEGIN
        g_chamadas := g_chamadas + 1;
        RETURN total_itens(p_id_pedido);
    END valor_pedido;

    FUNCTION valor_cliente (p_id_cliente IN clientes.id_cliente%TYPE) RETURN NUMBER IS
        v_total NUMBER;
    BEGIN
        g_chamadas := g_chamadas + 1;
        SELECT NVL(SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)), 0)
          INTO v_total
          FROM pedidos p
          JOIN itens_pedido i ON i.id_pedido = p.id_pedido
         WHERE p.id_cliente = p_id_cliente
           AND p.status <> c_status_cancelado;
        RETURN v_total;
    END valor_cliente;

    PROCEDURE validar_credito (
        p_id_cliente IN clientes.id_cliente%TYPE,
        p_valor_novo IN NUMBER
    ) IS
        v_limite    clientes.limite_credito%TYPE;
        v_em_aberto NUMBER;
    BEGIN
        g_chamadas := g_chamadas + 1;

        SELECT limite_credito INTO v_limite FROM clientes WHERE id_cliente = p_id_cliente;

        SELECT NVL(SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)), 0)
          INTO v_em_aberto
          FROM pedidos p
          JOIN itens_pedido i ON i.id_pedido = p.id_pedido
         WHERE p.id_cliente = p_id_cliente
           AND p.status IN ('ABERTO', 'FATURADO');

        IF v_em_aberto + p_valor_novo > v_limite THEN
            RAISE_APPLICATION_ERROR(-20101,
                'Cliente ' || p_id_cliente || ': em aberto ' || v_em_aberto
                || ' + novo ' || p_valor_novo || ' passa do limite ' || v_limite);
        END IF;
    END validar_credito;

    FUNCTION formatar (p_valor IN NUMBER) RETURN VARCHAR2 IS
    BEGIN
        RETURN TO_CHAR(p_valor, 'FM999G999G990D00', 'NLS_NUMERIC_CHARACTERS = '',.''');
    END formatar;

    FUNCTION formatar (p_data IN DATE) RETURN VARCHAR2 IS
    BEGIN
        RETURN TO_CHAR(p_data, 'DD/MM/YYYY');
    END formatar;

    FUNCTION chamadas RETURN PLS_INTEGER IS
    BEGIN
        RETURN g_chamadas;
    END chamadas;

BEGIN
    -- Inicialização: roda uma vez por sessão, na primeira referência.
    DBMS_OUTPUT.PUT_LINE('[tmp_pkg_vendas inicializada nesta sessão]');
END tmp_pkg_vendas;
/

-- 3. Chamadas, overloading e estado entre chamadas.
BEGIN
    DBMS_OUTPUT.PUT_LINE('Pedido 1008:  ' || tmp_pkg_vendas.formatar(tmp_pkg_vendas.valor_pedido(1008)));
    DBMS_OUTPUT.PUT_LINE('Cliente 10:   ' || tmp_pkg_vendas.formatar(tmp_pkg_vendas.valor_cliente(10)));
    DBMS_OUTPUT.PUT_LINE('Data:         ' || tmp_pkg_vendas.formatar(DATE '2026-11-27'));
    DBMS_OUTPUT.PUT_LINE('Chamadas:     ' || tmp_pkg_vendas.chamadas);
END;
/
-- Esperado:
--   [tmp_pkg_vendas inicializada nesta sessão]
--   Pedido 1008:  27.286,00
--   Cliente 10:   60.081,58
--   Data:         27/11/2026
--   Chamadas:     2

-- Outra chamada: a inicialização não roda de novo e o contador continua.
BEGIN
    DBMS_OUTPUT.PUT_LINE('Cliente 3:    ' || tmp_pkg_vendas.formatar(tmp_pkg_vendas.valor_cliente(3)));
    DBMS_OUTPUT.PUT_LINE('Chamadas:     ' || tmp_pkg_vendas.chamadas);
END;
/
-- Esperado: Cliente 3: 28.994,22 | Chamadas: 3

-- 4. Function de package em SQL: funciona. Constante de package em SQL: não.
-- Esperado: 1045.5
SELECT tmp_pkg_vendas.valor_pedido(1001) AS valor FROM dual;

-- Esperado: erro (ORA-06553 / PLS-00221: não é um procedimento ou está indefinido)
SELECT tmp_pkg_vendas.c_status_cancelado FROM dual;

-- 5. Rotina privada não é visível de fora.
BEGIN
    DBMS_OUTPUT.PUT_LINE(tmp_pkg_vendas.total_itens(1001));
END;
/
-- Esperado: PLS-00302 (o componente 'TOTAL_ITENS' deve ser declarado)

-- 6. Exceção pública: o chamador trata por nome.
BEGIN
    tmp_pkg_vendas.validar_credito(9, 3000);
    DBMS_OUTPUT.PUT_LINE('3000 para o cliente 9: aprovado');

    tmp_pkg_vendas.validar_credito(9, 3500);
    DBMS_OUTPUT.PUT_LINE('não chega aqui');
EXCEPTION
    WHEN tmp_pkg_vendas.e_limite_excedido THEN
        DBMS_OUTPUT.PUT_LINE('Recusado: ' || SQLERRM);
END;
/
-- Esperado:
--   3000 para o cliente 9: aprovado
--   Recusado: ORA-20101: Cliente 9: em aberto 899 + novo 3500 passa do limite 4000

-- 7. ORA-04068: estado descartado por recompilação em outra sessão.
--
--    Sessão A (esta): o estado já está carregado (contador = 6 depois do passo 6).
--
--    Sessão B: recompilar o corpo.
--        ALTER PACKAGE tmp_pkg_vendas COMPILE BODY;
--
--    Sessão A, de novo:
--        EXEC DBMS_OUTPUT.PUT_LINE(tmp_pkg_vendas.chamadas)
--        Esperado: ORA-04068 (o estado existente dos pacotes foi descartado),
--                  acompanhado de ORA-04061/ORA-04065 conforme a versão.
--
--        EXEC DBMS_OUTPUT.PUT_LINE(tmp_pkg_vendas.chamadas)
--        Esperado: [tmp_pkg_vendas inicializada nesta sessão] e 0
--                  (a segunda chamada funciona, com estado novo)

-- 8. Overloading ambíguo: tipos da mesma família.
CREATE OR REPLACE PACKAGE tmp_pkg_ambiguo IS
    PROCEDURE p (x IN NUMBER);
    PROCEDURE p (x IN INTEGER);
END tmp_pkg_ambiguo;
/

CREATE OR REPLACE PACKAGE BODY tmp_pkg_ambiguo IS
    PROCEDURE p (x IN NUMBER)  IS BEGIN DBMS_OUTPUT.PUT_LINE('NUMBER');  END;
    PROCEDURE p (x IN INTEGER) IS BEGIN DBMS_OUTPUT.PUT_LINE('INTEGER'); END;
END tmp_pkg_ambiguo;
/

BEGIN
    tmp_pkg_ambiguo.p(1);
END;
/
-- Esperado: PLS-00307 (muitas declarações de 'P' correspondem a esta chamada)
--           A package compila; o erro aparece na chamada.

-- 9. Estado das packages no dicionário.
-- Esperado: PACKAGE e PACKAGE BODY de cada uma, VALID
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name IN ('TMP_PKG_VENDAS', 'TMP_PKG_AMBIGUO')
 ORDER BY object_name, object_type;

DROP PACKAGE tmp_pkg_ambiguo;
DROP PACKAGE tmp_pkg_vendas;
