-- =============================================================================
-- Projeto : 05 — API em PL/SQL com utPLSQL — testes de aceite sem framework
-- Seção   : 16-mini-projetos
-- Versão  : 19c
-- Requer  : instalação completa com a carga de exemplo (03-carga.sql)
--
-- Os mesmos comportamentos da suite utPLSQL (05), num bloco que roda em qualquer
-- banco, sem instalar nada. Termina com ROLLBACK.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    v_total    PLS_INTEGER := 0;
    v_falhas   PLS_INTEGER := 0;
    v_id       api_pkg_clientes.t_id;
    v_cliente  api_pkg_clientes.t_cliente;
    v_cursor   SYS_REFCURSOR;
    v_json     VARCHAR2(4000);
    v_nomes    VARCHAR2(4000);
    v_qtd      PLS_INTEGER;

    PROCEDURE conferir (p_teste IN VARCHAR2, p_ok IN BOOLEAN) IS
    BEGIN
        v_total := v_total + 1;
        IF NVL(p_ok, FALSE) THEN
            DBMS_OUTPUT.PUT_LINE('OK      ' || p_teste);
        ELSE
            v_falhas := v_falhas + 1;
            DBMS_OUTPUT.PUT_LINE('FALHOU  ' || p_teste);
        END IF;
    END conferir;

    PROCEDURE conferir_erro (
        p_teste    IN VARCHAR2,
        p_esperado IN PLS_INTEGER,
        p_sqlcode  IN PLS_INTEGER,
        p_sqlerrm  IN VARCHAR2
    ) IS
    BEGIN
        conferir(p_teste || ' (ORA-' || TO_CHAR(-p_esperado, 'FM00000') || ')'
                 || CASE WHEN p_sqlcode <> p_esperado THEN ' — veio: ' || p_sqlerrm END,
                 p_sqlcode = p_esperado);
    END conferir_erro;

    FUNCTION id_por_documento (p_documento IN VARCHAR2) RETURN NUMBER IS
        v NUMBER;
    BEGIN
        SELECT id_cliente INTO v FROM api_clientes WHERE documento = p_documento;
        RETURN v;
    END id_por_documento;

    -- Lê o cursor de listar e devolve os nomes separados por '|', e a quantidade.
    PROCEDURE ler_lista (p_cursor IN OUT SYS_REFCURSOR, p_nomes OUT VARCHAR2, p_qtd OUT PLS_INTEGER) IS
        v_id_cli NUMBER;
        v_nome   VARCHAR2(100);
        v_uf     VARCHAR2(2);
        v_ativo  VARCHAR2(1);
        v_versao NUMBER;
    BEGIN
        p_qtd := 0;
        LOOP
            FETCH p_cursor INTO v_id_cli, v_nome, v_uf, v_ativo, v_versao;
            EXIT WHEN p_cursor%NOTFOUND;
            p_qtd   := p_qtd + 1;
            p_nomes := p_nomes || CASE WHEN p_qtd > 1 THEN '|' END || v_nome;
        END LOOP;
        CLOSE p_cursor;
    END ler_lista;
BEGIN
    -- Consulta -----------------------------------------------------------------
    v_cursor := api_pkg_clientes.listar;
    ler_lista(v_cursor, v_nomes, v_qtd);
    conferir('T01 carga: 5 clientes', v_qtd = 5);

    v_cursor := api_pkg_clientes.listar(p_uf => 'sp');
    ler_lista(v_cursor, v_nomes, v_qtd);
    conferir('T02 filtro por UF (minúscula aceita)',
             v_nomes = 'Mercado Ponto Certo Ltda|Pessoa Física 02');

    v_cursor := api_pkg_clientes.listar(p_pagina => 2, p_tamanho => 2);
    ler_lista(v_cursor, v_nomes, v_qtd);
    conferir('T03 página 2 de tamanho 2', v_nomes = 'Mercado Ponto Certo Ltda|Pessoa Física 01');

    v_cursor := api_pkg_clientes.listar(p_nome_contem => 'física');
    ler_lista(v_cursor, v_nomes, v_qtd);
    conferir('T04 nome contém, sem diferenciar maiúsculas', v_qtd = 2);

    v_cursor := api_pkg_clientes.listar(p_nome_contem => '%');
    ler_lista(v_cursor, v_nomes, v_qtd);
    conferir('T05 % no filtro é literal, não curinga', v_qtd = 0);

    BEGIN
        v_cursor := api_pkg_clientes.listar(p_tamanho => 500);
        conferir('T06 tamanho de página acima de 100 recusado', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T06 tamanho de página acima de 100 recusado', -20510, SQLCODE, SQLERRM);
    END;

    v_cliente := api_pkg_clientes.obter(id_por_documento('11222333000181'));
    conferir('T07 obter: normalizado na gravação (tipo J, UF e e-mail ajustados, versão 1)',
             v_cliente.tipo_pessoa = 'J' AND v_cliente.uf = 'SP'
             AND v_cliente.email = 'compras@pontocerto.example' AND v_cliente.versao = 1);

    v_json := api_pkg_clientes.obter_json(id_por_documento('52998224725'));
    conferir('T08 JSON com documento, ativo booleano e e-mail nulo',
             JSON_VALUE(v_json, '$.documento') = '52998224725'
             AND JSON_VALUE(v_json, '$.ativo') = 'true'
             AND JSON_VALUE(v_json, '$.email') IS NULL
             AND JSON_VALUE(v_json, '$.nome') = 'Pessoa Física 01');

    BEGIN
        v_cliente := api_pkg_clientes.obter(-1);
        conferir('T09 obter inexistente', FALSE);
    EXCEPTION
        -- Capturada pelo nome declarado na especificação da package.
        WHEN api_pkg_clientes.e_cliente_inexistente THEN
            conferir('T09 obter inexistente (ORA-20505, capturada por nome)', TRUE);
        WHEN OTHERS THEN
            conferir_erro('T09 obter inexistente', -20505, SQLCODE, SQLERRM);
    END;

    -- Criação e validação -------------------------------------------------------
    v_id := api_pkg_clientes.criar('Novo Cliente', '111.444.777-35', 'go');
    v_cliente := api_pkg_clientes.obter(v_id);
    conferir('T10 criar: CPF sem máscara, tipo F, limite padrão 0',
             v_cliente.documento = '11144477735' AND v_cliente.tipo_pessoa = 'F'
             AND v_cliente.limite_credito = 0 AND v_cliente.uf = 'GO');

    BEGIN
        v_id := api_pkg_clientes.criar('   ', '98765432100', 'SP');
        conferir('T11 nome em branco recusado', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T11 nome em branco recusado', -20501, SQLCODE, SQLERRM);
    END;

    FOR r IN (SELECT '98765432101' AS doc FROM dual UNION ALL
              SELECT '11111111111'        FROM dual UNION ALL
              SELECT '1234567890'         FROM dual UNION ALL
              SELECT '11222333000180'     FROM dual UNION ALL
              SELECT NULL                 FROM dual) LOOP
        BEGIN
            v_id := api_pkg_clientes.criar('Cliente', r.doc, 'SP');
            conferir('T12 documento ' || NVL(r.doc, 'nulo') || ' recusado', FALSE);
        EXCEPTION WHEN OTHERS THEN
            conferir_erro('T12 documento ' || NVL(r.doc, 'nulo') || ' recusado', -20502, SQLCODE, SQLERRM);
        END;
    END LOOP;

    BEGIN
        v_id := api_pkg_clientes.criar('Duplicado', '529 982 247 25', 'SP');
        conferir('T13 documento já cadastrado (com outra máscara) recusado', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T13 documento já cadastrado (com outra máscara) recusado', -20503, SQLCODE, SQLERRM);
    END;

    FOR r IN (SELECT 'sem-arroba.example' AS email FROM dual UNION ALL
              SELECT 'dois@@arrobas.example'        FROM dual UNION ALL
              SELECT 'com espaco@x.example'         FROM dual UNION ALL
              SELECT 'sem@ponto'                    FROM dual) LOOP
        BEGIN
            v_id := api_pkg_clientes.criar('Cliente', '98765432100', 'SP', r.email);
            conferir('T14 e-mail ' || r.email || ' recusado', FALSE);
        EXCEPTION WHEN OTHERS THEN
            conferir_erro('T14 e-mail ' || r.email || ' recusado', -20504, SQLCODE, SQLERRM);
        END;
    END LOOP;

    BEGIN
        v_id := api_pkg_clientes.criar('Cliente', '98765432100', 'XX');
        conferir('T15 UF inexistente recusada', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T15 UF inexistente recusada', -20507, SQLCODE, SQLERRM);
    END;

    BEGIN
        v_id := api_pkg_clientes.criar('Cliente', '98765432100', 'SP', NULL, -1);
        conferir('T16 limite negativo recusado', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T16 limite negativo recusado', -20508, SQLCODE, SQLERRM);
    END;

    -- Alteração com concorrência otimista ---------------------------------------
    v_id      := id_por_documento('45371296000195');
    v_cliente := api_pkg_clientes.obter(v_id);
    api_pkg_clientes.alterar(v_id, v_cliente.versao, 'Atacado Sul Ltda', 'RS', NULL, 12000);
    v_cliente := api_pkg_clientes.obter(v_id);
    conferir('T17 alterar com a versão lida: versão 2 e auditoria preenchida',
             v_cliente.versao = 2 AND v_cliente.nome = 'Atacado Sul Ltda'
             AND v_cliente.alterado_em IS NOT NULL);

    -- Outra tela tinha lido a versão 1 e tenta salvar.
    BEGIN
        api_pkg_clientes.alterar(v_id, 1, 'Atacado Sul S.A.', 'RS', NULL, 15000);
        conferir('T18 alteração com versão velha recusada', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T18 alteração com versão velha recusada', -20506, SQLCODE, SQLERRM);
    END;
    v_cliente := api_pkg_clientes.obter(v_id);
    conferir('T19 a alteração recusada não sobrescreveu a anterior',
             v_cliente.nome = 'Atacado Sul Ltda' AND v_cliente.limite_credito = 12000);

    BEGIN
        api_pkg_clientes.alterar(-1, 1, 'X', 'SP', NULL, 0);
        conferir('T20 alterar inexistente', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T20 alterar inexistente', -20505, SQLCODE, SQLERRM);
    END;

    api_pkg_clientes.inativar(v_id, 2);
    v_cliente := api_pkg_clientes.obter(v_id);
    conferir('T21 inativar: ativo N, versão 3', v_cliente.ativo = 'N' AND v_cliente.versao = 3);

    BEGIN
        api_pkg_clientes.alterar(v_id, 3, 'Atacado Sul Ltda', 'RS', NULL, 1);
        conferir('T22 alterar cliente inativo recusado', FALSE);
    EXCEPTION WHEN OTHERS THEN conferir_erro('T22 alterar cliente inativo recusado', -20509, SQLCODE, SQLERRM);
    END;

    DBMS_OUTPUT.PUT_LINE('----');
    DBMS_OUTPUT.PUT_LINE(v_total - v_falhas || ' de ' || v_total || ' testes passaram');
END;
/

ROLLBACK;
