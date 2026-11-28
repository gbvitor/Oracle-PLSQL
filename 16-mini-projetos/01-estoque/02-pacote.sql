-- =============================================================================
-- Projeto : 01 — Controle de estoque — package EST_PKG_ESTOQUE
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : 01-tabelas.sql; CREATE PROCEDURE
--
-- Toda movimentação passa por aqui. A package não faz COMMIT: quem chama decide
-- a transação. Cada operação é atômica (SAVEPOINT): se falhar, nada dela fica.
-- =============================================================================

CREATE OR REPLACE PACKAGE est_pkg_estoque AS

    e_saldo_insuficiente   EXCEPTION;
    e_quantidade_invalida  EXCEPTION;
    e_produto_invalido     EXCEPTION;
    e_deposito_invalido    EXCEPTION;
    e_mesmo_deposito       EXCEPTION;
    e_motivo_obrigatorio   EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_saldo_insuficiente,  -20101);
    PRAGMA EXCEPTION_INIT(e_quantidade_invalida, -20102);
    PRAGMA EXCEPTION_INIT(e_produto_invalido,    -20103);
    PRAGMA EXCEPTION_INIT(e_deposito_invalido,   -20104);
    PRAGMA EXCEPTION_INIT(e_mesmo_deposito,      -20105);
    PRAGMA EXCEPTION_INIT(e_motivo_obrigatorio,  -20106);

    SUBTYPE t_id_movimento IS est_movimentos.id_movimento%TYPE;

    FUNCTION entrada (
        p_id_produto  IN est_produtos.id_produto%TYPE,
        p_id_deposito IN est_depositos.id_deposito%TYPE,
        p_quantidade  IN NUMBER,
        p_documento   IN VARCHAR2 DEFAULT NULL,
        p_data        IN DATE     DEFAULT SYSDATE
    ) RETURN t_id_movimento;

    FUNCTION saida (
        p_id_produto  IN est_produtos.id_produto%TYPE,
        p_id_deposito IN est_depositos.id_deposito%TYPE,
        p_quantidade  IN NUMBER,
        p_documento   IN VARCHAR2 DEFAULT NULL,
        p_data        IN DATE     DEFAULT SYSDATE
    ) RETURN t_id_movimento;

    -- Grava a saída na origem e a entrada no destino com o mesmo id_transferencia.
    -- Devolve o id_transferencia.
    FUNCTION transferir (
        p_id_produto IN est_produtos.id_produto%TYPE,
        p_origem     IN est_depositos.id_deposito%TYPE,
        p_destino    IN est_depositos.id_deposito%TYPE,
        p_quantidade IN NUMBER,
        p_documento  IN VARCHAR2 DEFAULT NULL,
        p_data       IN DATE     DEFAULT SYSDATE
    ) RETURN NUMBER;

    -- Inventário: informa a quantidade contada; grava a diferença como AJUSTE.
    -- Devolve NULL se a contagem bate com o saldo (nenhum movimento gravado).
    FUNCTION ajustar (
        p_id_produto         IN est_produtos.id_produto%TYPE,
        p_id_deposito        IN est_depositos.id_deposito%TYPE,
        p_quantidade_contada IN NUMBER,
        p_motivo             IN VARCHAR2,
        p_data               IN DATE DEFAULT SYSDATE
    ) RETURN t_id_movimento;

    -- Saldo de um depósito ou, sem depósito, de todos. Pode ser usada em SQL.
    FUNCTION saldo (
        p_id_produto  IN est_produtos.id_produto%TYPE,
        p_id_deposito IN est_depositos.id_deposito%TYPE DEFAULT NULL
    ) RETURN NUMBER;

END est_pkg_estoque;
/

CREATE OR REPLACE PACKAGE BODY est_pkg_estoque AS

    -- -------------------------------------------------------------------------
    -- Validações
    -- -------------------------------------------------------------------------
    PROCEDURE validar_quantidade (p_quantidade IN NUMBER, p_aceita_zero IN BOOLEAN DEFAULT FALSE) IS
    BEGIN
        IF p_quantidade IS NULL
           OR p_quantidade < 0
           OR (p_quantidade = 0 AND NOT p_aceita_zero)
           OR p_quantidade <> ROUND(p_quantidade, 3) THEN
            RAISE_APPLICATION_ERROR(-20102,
                'Quantidade inválida: ' || NVL(TO_CHAR(p_quantidade), 'nula')
                || ' (deve ser positiva, com até 3 casas decimais)');
        END IF;
    END validar_quantidade;

    PROCEDURE validar_produto (p_id_produto IN est_produtos.id_produto%TYPE) IS
        v_ativo est_produtos.ativo%TYPE;
    BEGIN
        SELECT ativo INTO v_ativo FROM est_produtos WHERE id_produto = p_id_produto;
        IF v_ativo <> 'S' THEN
            RAISE_APPLICATION_ERROR(-20103, 'Produto inativo: ' || p_id_produto);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20103, 'Produto inexistente: ' || NVL(TO_CHAR(p_id_produto), 'nulo'));
    END validar_produto;

    PROCEDURE validar_deposito (p_id_deposito IN est_depositos.id_deposito%TYPE) IS
        v_existe PLS_INTEGER;
    BEGIN
        SELECT 1 INTO v_existe FROM est_depositos WHERE id_deposito = p_id_deposito;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20104, 'Depósito inexistente: ' || NVL(TO_CHAR(p_id_deposito), 'nulo'));
    END validar_deposito;

    -- -------------------------------------------------------------------------
    -- Trava a linha de saldo (criando-a com zero se ainda não existir) e devolve
    -- a quantidade. Duas sessões movimentando o mesmo produto e depósito ficam
    -- em fila aqui: a segunda espera o COMMIT ou ROLLBACK da primeira.
    -- -------------------------------------------------------------------------
    FUNCTION travar_saldo (
        p_id_produto  IN est_produtos.id_produto%TYPE,
        p_id_deposito IN est_depositos.id_deposito%TYPE
    ) RETURN NUMBER IS
        v_quantidade est_saldos.quantidade%TYPE;
    BEGIN
        BEGIN
            INSERT INTO est_saldos (id_produto, id_deposito, quantidade)
            VALUES (p_id_produto, p_id_deposito, 0);
        EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
                NULL;
        END;

        SELECT quantidade
          INTO v_quantidade
          FROM est_saldos
         WHERE id_produto = p_id_produto
           AND id_deposito = p_id_deposito
           FOR UPDATE;

        RETURN v_quantidade;
    END travar_saldo;

    -- -------------------------------------------------------------------------
    -- Grava um movimento e atualiza o saldo. Chamado só depois das validações.
    -- -------------------------------------------------------------------------
    FUNCTION gravar (
        p_id_produto       IN NUMBER,
        p_id_deposito      IN NUMBER,
        p_tipo             IN VARCHAR2,
        p_sinal            IN NUMBER,
        p_quantidade       IN NUMBER,
        p_documento        IN VARCHAR2,
        p_observacao       IN VARCHAR2,
        p_data             IN DATE,
        p_id_transferencia IN NUMBER DEFAULT NULL
    ) RETURN t_id_movimento IS
        v_saldo est_saldos.quantidade%TYPE;
        v_id    t_id_movimento;
    BEGIN
        v_saldo := travar_saldo(p_id_produto, p_id_deposito);

        IF p_sinal = -1 AND v_saldo < p_quantidade THEN
            RAISE_APPLICATION_ERROR(-20101,
                'Saldo insuficiente: produto ' || p_id_produto || ', depósito ' || p_id_deposito
                || ', saldo ' || TO_CHAR(v_saldo) || ', solicitado ' || TO_CHAR(p_quantidade));
        END IF;

        INSERT INTO est_movimentos (id_produto, id_deposito, tipo, sinal, quantidade,
                                    data_movimento, documento, observacao, id_transferencia)
        VALUES (p_id_produto, p_id_deposito, p_tipo, p_sinal, p_quantidade,
                p_data, p_documento, p_observacao, p_id_transferencia)
        RETURNING id_movimento INTO v_id;

        UPDATE est_saldos
           SET quantidade    = quantidade + p_sinal * p_quantidade,
               atualizado_em = SYSTIMESTAMP
         WHERE id_produto  = p_id_produto
           AND id_deposito = p_id_deposito;

        RETURN v_id;
    END gravar;

    -- -------------------------------------------------------------------------
    -- Operações públicas
    -- -------------------------------------------------------------------------
    FUNCTION entrada (
        p_id_produto  IN est_produtos.id_produto%TYPE,
        p_id_deposito IN est_depositos.id_deposito%TYPE,
        p_quantidade  IN NUMBER,
        p_documento   IN VARCHAR2 DEFAULT NULL,
        p_data        IN DATE     DEFAULT SYSDATE
    ) RETURN t_id_movimento IS
        v_id t_id_movimento;
    BEGIN
        SAVEPOINT sp_est_entrada;
        validar_quantidade(p_quantidade);
        validar_produto(p_id_produto);
        validar_deposito(p_id_deposito);
        v_id := gravar(p_id_produto, p_id_deposito, 'ENTRADA', 1, p_quantidade,
                       p_documento, NULL, p_data);
        RETURN v_id;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sp_est_entrada;
            RAISE;
    END entrada;

    FUNCTION saida (
        p_id_produto  IN est_produtos.id_produto%TYPE,
        p_id_deposito IN est_depositos.id_deposito%TYPE,
        p_quantidade  IN NUMBER,
        p_documento   IN VARCHAR2 DEFAULT NULL,
        p_data        IN DATE     DEFAULT SYSDATE
    ) RETURN t_id_movimento IS
        v_id t_id_movimento;
    BEGIN
        SAVEPOINT sp_est_saida;
        validar_quantidade(p_quantidade);
        validar_produto(p_id_produto);
        validar_deposito(p_id_deposito);
        v_id := gravar(p_id_produto, p_id_deposito, 'SAIDA', -1, p_quantidade,
                       p_documento, NULL, p_data);
        RETURN v_id;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sp_est_saida;
            RAISE;
    END saida;

    FUNCTION transferir (
        p_id_produto IN est_produtos.id_produto%TYPE,
        p_origem     IN est_depositos.id_deposito%TYPE,
        p_destino    IN est_depositos.id_deposito%TYPE,
        p_quantidade IN NUMBER,
        p_documento  IN VARCHAR2 DEFAULT NULL,
        p_data       IN DATE     DEFAULT SYSDATE
    ) RETURN NUMBER IS
        v_id_transf NUMBER;
        v_id        t_id_movimento;
        v_ignorar   NUMBER;
    BEGIN
        SAVEPOINT sp_est_transferir;
        validar_quantidade(p_quantidade);
        validar_produto(p_id_produto);
        validar_deposito(p_origem);
        validar_deposito(p_destino);
        IF p_origem = p_destino THEN
            RAISE_APPLICATION_ERROR(-20105, 'Origem e destino iguais: ' || p_origem);
        END IF;

        -- Trava as duas linhas sempre na mesma ordem (menor depósito primeiro):
        -- duas transferências cruzadas (1 para 2 e 2 para 1) não entram em deadlock.
        v_ignorar := travar_saldo(p_id_produto, LEAST(p_origem, p_destino));
        v_ignorar := travar_saldo(p_id_produto, GREATEST(p_origem, p_destino));

        v_id_transf := est_seq_transferencia.NEXTVAL;
        v_id := gravar(p_id_produto, p_origem, 'TRANSF_SAIDA', -1, p_quantidade,
                       p_documento, 'Para o depósito ' || p_destino, p_data, v_id_transf);
        v_id := gravar(p_id_produto, p_destino, 'TRANSF_ENTRADA', 1, p_quantidade,
                       p_documento, 'Do depósito ' || p_origem, p_data, v_id_transf);
        RETURN v_id_transf;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sp_est_transferir;
            RAISE;
    END transferir;

    FUNCTION ajustar (
        p_id_produto         IN est_produtos.id_produto%TYPE,
        p_id_deposito        IN est_depositos.id_deposito%TYPE,
        p_quantidade_contada IN NUMBER,
        p_motivo             IN VARCHAR2,
        p_data               IN DATE DEFAULT SYSDATE
    ) RETURN t_id_movimento IS
        v_saldo     est_saldos.quantidade%TYPE;
        v_diferenca NUMBER;
        v_id        t_id_movimento;
    BEGIN
        SAVEPOINT sp_est_ajustar;
        validar_quantidade(p_quantidade_contada, p_aceita_zero => TRUE);
        validar_produto(p_id_produto);
        validar_deposito(p_id_deposito);
        IF TRIM(p_motivo) IS NULL THEN
            RAISE_APPLICATION_ERROR(-20106, 'Ajuste de inventário exige motivo');
        END IF;

        v_saldo     := travar_saldo(p_id_produto, p_id_deposito);
        v_diferenca := p_quantidade_contada - v_saldo;

        IF v_diferenca = 0 THEN
            RETURN NULL;
        END IF;

        v_id := gravar(p_id_produto, p_id_deposito, 'AJUSTE', SIGN(v_diferenca), ABS(v_diferenca),
                       NULL, p_motivo, p_data);
        RETURN v_id;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sp_est_ajustar;
            RAISE;
    END ajustar;

    FUNCTION saldo (
        p_id_produto  IN est_produtos.id_produto%TYPE,
        p_id_deposito IN est_depositos.id_deposito%TYPE DEFAULT NULL
    ) RETURN NUMBER IS
        v_quantidade NUMBER;
    BEGIN
        SELECT NVL(SUM(quantidade), 0)
          INTO v_quantidade
          FROM est_saldos
         WHERE id_produto = p_id_produto
           AND (p_id_deposito IS NULL OR id_deposito = p_id_deposito);
        RETURN v_quantidade;
    END saldo;

END est_pkg_estoque;
/

SHOW ERRORS PACKAGE BODY est_pkg_estoque
