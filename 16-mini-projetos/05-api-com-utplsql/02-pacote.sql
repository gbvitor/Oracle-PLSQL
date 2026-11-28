-- =============================================================================
-- Projeto : 05 — API em PL/SQL com utPLSQL — package API_PKG_CLIENTES
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : 01-tabelas.sql; CREATE PROCEDURE
--
-- A "API" do cadastro de clientes: a aplicação não grava na tabela, chama a
-- package. Validação e normalização num lugar só, erros com código e nome,
-- controle de concorrência otimista por versão, consulta paginada e JSON.
-- =============================================================================

CREATE OR REPLACE PACKAGE api_pkg_clientes AS

    e_nome_obrigatorio     EXCEPTION;  PRAGMA EXCEPTION_INIT(e_nome_obrigatorio,     -20501);
    e_documento_invalido   EXCEPTION;  PRAGMA EXCEPTION_INIT(e_documento_invalido,   -20502);
    e_documento_duplicado  EXCEPTION;  PRAGMA EXCEPTION_INIT(e_documento_duplicado,  -20503);
    e_email_invalido       EXCEPTION;  PRAGMA EXCEPTION_INIT(e_email_invalido,       -20504);
    e_cliente_inexistente  EXCEPTION;  PRAGMA EXCEPTION_INIT(e_cliente_inexistente,  -20505);
    e_alterado_por_outro   EXCEPTION;  PRAGMA EXCEPTION_INIT(e_alterado_por_outro,   -20506);
    e_uf_invalida          EXCEPTION;  PRAGMA EXCEPTION_INIT(e_uf_invalida,          -20507);
    e_limite_invalido      EXCEPTION;  PRAGMA EXCEPTION_INIT(e_limite_invalido,      -20508);
    e_cliente_inativo      EXCEPTION;  PRAGMA EXCEPTION_INIT(e_cliente_inativo,      -20509);
    e_parametro_invalido   EXCEPTION;  PRAGMA EXCEPTION_INIT(e_parametro_invalido,   -20510);

    SUBTYPE t_id      IS api_clientes.id_cliente%TYPE;
    SUBTYPE t_cliente IS api_clientes%ROWTYPE;

    -- O tipo de pessoa sai do documento: 11 posições = CPF (F), 14 = CNPJ (J).
    FUNCTION criar (
        p_nome      IN VARCHAR2,
        p_documento IN VARCHAR2,
        p_uf        IN VARCHAR2,
        p_email     IN VARCHAR2 DEFAULT NULL,
        p_limite    IN NUMBER   DEFAULT 0
    ) RETURN t_id;

    -- p_versao é a versão que o chamador leu. Se outro alterou depois, ORA-20506.
    -- O documento não se altera: é a identidade do cliente.
    PROCEDURE alterar (
        p_id     IN t_id,
        p_versao IN NUMBER,
        p_nome   IN VARCHAR2,
        p_uf     IN VARCHAR2,
        p_email  IN VARCHAR2,
        p_limite IN NUMBER
    );

    PROCEDURE inativar (p_id IN t_id, p_versao IN NUMBER);

    FUNCTION obter      (p_id IN t_id) RETURN t_cliente;
    FUNCTION obter_json (p_id IN t_id) RETURN VARCHAR2;

    -- Colunas: id_cliente, nome, uf, ativo, versao. Ordem: nome, id.
    -- Filtros opcionais; p_nome_contem é literal (% e _ não são curingas).
    FUNCTION listar (
        p_uf          IN VARCHAR2    DEFAULT NULL,
        p_nome_contem IN VARCHAR2    DEFAULT NULL,
        p_pagina      IN PLS_INTEGER DEFAULT 1,
        p_tamanho     IN PLS_INTEGER DEFAULT 20
    ) RETURN SYS_REFCURSOR;

    -- Expostas para teste e para validação na tela antes de chamar criar.
    FUNCTION documento_valido (p_documento IN VARCHAR2) RETURN BOOLEAN;
    FUNCTION normalizar_documento (p_documento IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;

END api_pkg_clientes;
/

CREATE OR REPLACE PACKAGE BODY api_pkg_clientes AS

    c_ufs CONSTANT VARCHAR2(200) :=
        ',AC,AL,AP,AM,BA,CE,DF,ES,GO,MA,MT,MS,MG,PA,PB,PR,PE,PI,RJ,RN,RS,RO,RR,SC,SP,SE,TO,';

    TYPE t_pesos IS TABLE OF PLS_INTEGER;

    -- -------------------------------------------------------------------------
    -- Documento (mesmo cálculo do caso 09 da seção 15)
    -- -------------------------------------------------------------------------
    FUNCTION dv_mod11 (p_base IN VARCHAR2, p_pesos IN t_pesos) RETURN PLS_INTEGER IS
        v_soma  PLS_INTEGER := 0;
        v_resto PLS_INTEGER;
    BEGIN
        FOR i IN 1 .. p_pesos.COUNT LOOP
            v_soma := v_soma + (ASCII(SUBSTR(p_base, i, 1)) - 48) * p_pesos(i);
        END LOOP;
        v_resto := MOD(v_soma, 11);
        RETURN CASE WHEN v_resto < 2 THEN 0 ELSE 11 - v_resto END;
    END dv_mod11;

    FUNCTION normalizar_documento (p_documento IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    BEGIN
        RETURN UPPER(REGEXP_REPLACE(p_documento, '[[:space:]./-]', ''));
    END normalizar_documento;

    FUNCTION documento_valido (p_documento IN VARCHAR2) RETURN BOOLEAN IS
        v_doc  VARCHAR2(4000) := normalizar_documento(p_documento);
        v_base VARCHAR2(14);
    BEGIN
        IF v_doc IS NULL OR v_doc = RPAD(SUBSTR(v_doc, 1, 1), LENGTH(v_doc), SUBSTR(v_doc, 1, 1)) THEN
            RETURN FALSE;
        ELSIF REGEXP_LIKE(v_doc, '^[0-9]{11}$') THEN
            v_base := SUBSTR(v_doc, 1, 9);
            v_base := v_base || dv_mod11(v_base, t_pesos(10, 9, 8, 7, 6, 5, 4, 3, 2));
            v_base := v_base || dv_mod11(v_base, t_pesos(11, 10, 9, 8, 7, 6, 5, 4, 3, 2));
        ELSIF REGEXP_LIKE(v_doc, '^[0-9A-Z]{12}[0-9]{2}$') THEN
            v_base := SUBSTR(v_doc, 1, 12);
            v_base := v_base || dv_mod11(v_base, t_pesos(5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2));
            v_base := v_base || dv_mod11(v_base, t_pesos(6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2));
        ELSE
            RETURN FALSE;
        END IF;
        RETURN v_base = v_doc;
    END documento_valido;

    -- -------------------------------------------------------------------------
    -- Validação e normalização dos campos comuns a criar e alterar
    -- -------------------------------------------------------------------------
    PROCEDURE validar (
        p_nome   IN OUT VARCHAR2,
        p_uf     IN OUT VARCHAR2,
        p_email  IN OUT VARCHAR2,
        p_limite IN OUT NUMBER
    ) IS
    BEGIN
        p_nome := TRIM(REGEXP_REPLACE(p_nome, '[[:space:]]+', ' '));
        IF p_nome IS NULL THEN
            RAISE_APPLICATION_ERROR(-20501, 'Nome é obrigatório');
        END IF;

        p_uf := UPPER(TRIM(p_uf));
        IF p_uf IS NULL OR LENGTH(p_uf) <> 2 OR INSTR(c_ufs, ',' || p_uf || ',') = 0 THEN
            RAISE_APPLICATION_ERROR(-20507, 'UF inválida: ' || NVL(p_uf, 'nula'));
        END IF;

        p_email := LOWER(TRIM(p_email));
        IF p_email IS NOT NULL
           AND NOT REGEXP_LIKE(p_email, '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$') THEN
            RAISE_APPLICATION_ERROR(-20504, 'E-mail inválido: ' || p_email);
        END IF;

        IF p_limite IS NULL OR p_limite < 0 OR p_limite <> ROUND(p_limite, 2) THEN
            RAISE_APPLICATION_ERROR(-20508,
                'Limite de crédito inválido: ' || NVL(TO_CHAR(p_limite), 'nulo'));
        END IF;
    END validar;

    -- Depois de um UPDATE ... WHERE versao = :v que não achou linha: por quê?
    PROCEDURE diagnosticar_falha_de_versao (p_id IN t_id) IS
        v_ativo  api_clientes.ativo%TYPE;
        v_versao api_clientes.versao%TYPE;
    BEGIN
        SELECT ativo, versao INTO v_ativo, v_versao FROM api_clientes WHERE id_cliente = p_id;
        IF v_ativo = 'N' THEN
            RAISE_APPLICATION_ERROR(-20509, 'Cliente ' || p_id || ' está inativo');
        END IF;
        RAISE_APPLICATION_ERROR(-20506,
            'Cliente ' || p_id || ' foi alterado por outro usuário (versão atual ' || v_versao
            || '): leia de novo antes de alterar');
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20505, 'Cliente inexistente: ' || NVL(TO_CHAR(p_id), 'nulo'));
    END diagnosticar_falha_de_versao;

    -- -------------------------------------------------------------------------
    FUNCTION criar (
        p_nome      IN VARCHAR2,
        p_documento IN VARCHAR2,
        p_uf        IN VARCHAR2,
        p_email     IN VARCHAR2 DEFAULT NULL,
        p_limite    IN NUMBER   DEFAULT 0
    ) RETURN t_id IS
        v_nome   VARCHAR2(4000) := p_nome;
        v_uf     VARCHAR2(4000) := p_uf;
        v_email  VARCHAR2(4000) := p_email;
        v_limite NUMBER         := p_limite;
        v_doc    VARCHAR2(4000) := normalizar_documento(p_documento);
        v_id     t_id;
    BEGIN
        validar(v_nome, v_uf, v_email, v_limite);

        IF NOT documento_valido(v_doc) THEN
            RAISE_APPLICATION_ERROR(-20502, 'CPF/CNPJ inválido: ' || NVL(p_documento, 'nulo'));
        END IF;

        INSERT INTO api_clientes (tipo_pessoa, documento, nome, email, uf, limite_credito)
        VALUES (CASE LENGTH(v_doc) WHEN 11 THEN 'F' ELSE 'J' END,
                v_doc, v_nome, v_email, v_uf, v_limite)
        RETURNING id_cliente INTO v_id;

        RETURN v_id;
    EXCEPTION
        -- O UNIQUE é a garantia (duas sessões criando o mesmo documento ao mesmo tempo:
        -- a segunda espera e recebe o erro); aqui só se dá nome a ele.
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20503, 'Já existe cliente com o documento ' || v_doc);
    END criar;

    -- -------------------------------------------------------------------------
    PROCEDURE alterar (
        p_id     IN t_id,
        p_versao IN NUMBER,
        p_nome   IN VARCHAR2,
        p_uf     IN VARCHAR2,
        p_email  IN VARCHAR2,
        p_limite IN NUMBER
    ) IS
        v_nome   VARCHAR2(4000) := p_nome;
        v_uf     VARCHAR2(4000) := p_uf;
        v_email  VARCHAR2(4000) := p_email;
        v_limite NUMBER         := p_limite;
    BEGIN
        validar(v_nome, v_uf, v_email, v_limite);

        -- Concorrência otimista: só altera se ninguém alterou desde a leitura.
        -- Não segura trava entre a tela abrir e o usuário salvar.
        UPDATE api_clientes
           SET nome           = v_nome,
               uf             = v_uf,
               email          = v_email,
               limite_credito = v_limite,
               versao         = versao + 1,
               alterado_em    = SYSTIMESTAMP,
               alterado_por   = USER
         WHERE id_cliente = p_id
           AND versao     = p_versao
           AND ativo      = 'S';

        IF SQL%ROWCOUNT = 0 THEN
            diagnosticar_falha_de_versao(p_id);
        END IF;
    END alterar;

    PROCEDURE inativar (p_id IN t_id, p_versao IN NUMBER) IS
    BEGIN
        UPDATE api_clientes
           SET ativo        = 'N',
               versao       = versao + 1,
               alterado_em  = SYSTIMESTAMP,
               alterado_por = USER
         WHERE id_cliente = p_id
           AND versao     = p_versao
           AND ativo      = 'S';

        IF SQL%ROWCOUNT = 0 THEN
            diagnosticar_falha_de_versao(p_id);
        END IF;
    END inativar;

    -- -------------------------------------------------------------------------
    FUNCTION obter (p_id IN t_id) RETURN t_cliente IS
        v_cliente t_cliente;
    BEGIN
        SELECT * INTO v_cliente FROM api_clientes WHERE id_cliente = p_id;
        RETURN v_cliente;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20505, 'Cliente inexistente: ' || NVL(TO_CHAR(p_id), 'nulo'));
    END obter;

    FUNCTION obter_json (p_id IN t_id) RETURN VARCHAR2 IS
        v_json VARCHAR2(4000);
    BEGIN
        SELECT JSON_OBJECT(
                   'id'         VALUE id_cliente,
                   'tipoPessoa' VALUE tipo_pessoa,
                   'documento'  VALUE documento,
                   'nome'       VALUE nome,
                   'email'      VALUE email,
                   'uf'         VALUE uf,
                   'limite'     VALUE limite_credito,
                   'ativo'      VALUE CASE ativo WHEN 'S' THEN 'true' ELSE 'false' END FORMAT JSON,
                   'versao'     VALUE versao
                   NULL ON NULL)
          INTO v_json
          FROM api_clientes
         WHERE id_cliente = p_id;
        RETURN v_json;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20505, 'Cliente inexistente: ' || NVL(TO_CHAR(p_id), 'nulo'));
    END obter_json;

    -- -------------------------------------------------------------------------
    FUNCTION listar (
        p_uf          IN VARCHAR2    DEFAULT NULL,
        p_nome_contem IN VARCHAR2    DEFAULT NULL,
        p_pagina      IN PLS_INTEGER DEFAULT 1,
        p_tamanho     IN PLS_INTEGER DEFAULT 20
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
        v_padrao VARCHAR2(4000);
    BEGIN
        IF p_pagina IS NULL OR p_pagina < 1 OR p_tamanho IS NULL OR p_tamanho NOT BETWEEN 1 AND 100 THEN
            RAISE_APPLICATION_ERROR(-20510,
                'Paginação inválida: página ' || NVL(TO_CHAR(p_pagina), 'nula')
                || ', tamanho ' || NVL(TO_CHAR(p_tamanho), 'nulo') || ' (1 a 100)');
        END IF;

        -- O texto do usuário é literal: \ , % e _ são escapados para o LIKE.
        IF p_nome_contem IS NOT NULL THEN
            v_padrao := '%' || REPLACE(REPLACE(REPLACE(UPPER(p_nome_contem), '\', '\\'), '%', '\%'), '_', '\_') || '%';
        END IF;

        -- SQL estático com filtros opcionais: uma consulta só, binds, sem concatenar.
        OPEN v_cursor FOR
            SELECT id_cliente, nome, uf, ativo, versao
              FROM api_clientes
             WHERE (p_uf IS NULL OR uf = UPPER(TRIM(p_uf)))
               AND (v_padrao IS NULL OR UPPER(nome) LIKE v_padrao ESCAPE '\')
             ORDER BY nome, id_cliente
            OFFSET (p_pagina - 1) * p_tamanho ROWS
             FETCH NEXT p_tamanho ROWS ONLY;

        RETURN v_cursor;
    END listar;

END api_pkg_clientes;
/

SHOW ERRORS PACKAGE BODY api_pkg_clientes
