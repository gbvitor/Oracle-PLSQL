-- =============================================================================
-- Projeto : 05 — API em PL/SQL com utPLSQL — suite de testes utPLSQL
-- Seção   : 16-mini-projetos
-- Versão  : 19c; utPLSQL 3.1 ou superior
-- Requer  : utPLSQL instalado no banco (seção 09, tópico 17); 01 a 03
--
-- Cada teste roda dentro de um savepoint e é desfeito no fim (rollback automático,
-- o padrão do utPLSQL): a carga de exemplo não muda. O --%beforeeach cria, antes
-- de cada teste, um cliente próprio, para os testes não dependerem da carga.
-- =============================================================================

CREATE OR REPLACE PACKAGE test_api_pkg_clientes AS

    --%suite(API de clientes: api_pkg_clientes)
    --%suitepath(mini_projetos.api)

    --%beforeeach
    PROCEDURE criar_cliente_base;

    --%context(Criação e normalização)

        --%test(Grava o documento sem máscara e deduz o tipo de pessoa)
        PROCEDURE documento_normalizado;

        --%test(Normaliza nome, UF e e-mail)
        PROCEDURE campos_normalizados;

        --%test(Aceita CNPJ alfanumérico)
        PROCEDURE cnpj_alfanumerico;

    --%endcontext

    --%context(Validação)

        --%test(Nome em branco é recusado)
        --%throws(-20501)
        PROCEDURE nome_em_branco;

        --%test(CPF com dígito verificador errado é recusado)
        --%throws(-20502)
        PROCEDURE cpf_invalido;

        --%test(Documento já cadastrado, com outra máscara, é recusado)
        --%throws(-20503)
        PROCEDURE documento_duplicado;

        --%test(E-mail sem domínio é recusado)
        --%throws(-20504)
        PROCEDURE email_invalido;

        --%test(UF inexistente é recusada)
        --%throws(-20507)
        PROCEDURE uf_invalida;

        --%test(Limite negativo é recusado)
        --%throws(-20508)
        PROCEDURE limite_negativo;

        --%test(documento_valido: verdadeiro e falso)
        PROCEDURE funcao_documento_valido;

    --%endcontext

    --%context(Concorrência otimista)

        --%test(Alterar com a versão lida grava e soma 1 na versão)
        PROCEDURE alterar_soma_versao;

        --%test(Alterar com versão velha é recusado)
        --%throws(-20506)
        PROCEDURE versao_velha;

        --%test(Alterar cliente inativo é recusado)
        --%throws(-20509)
        PROCEDURE alterar_inativo;

        --%test(Alterar cliente inexistente é recusado)
        --%throws(-20505)
        PROCEDURE alterar_inexistente;

    --%endcontext

    --%context(Consulta)

        --%test(listar devolve as mesmas linhas que a consulta direta)
        PROCEDURE listar_igual_consulta;

        --%test(Porcentagem no filtro de nome é literal)
        PROCEDURE porcentagem_literal;

        --%test(Tamanho de página acima de 100 é recusado)
        --%throws(-20510)
        PROCEDURE pagina_grande;

        --%test(JSON com ativo booleano e e-mail)
        PROCEDURE json_do_cliente;

    --%endcontext

END test_api_pkg_clientes;
/

CREATE OR REPLACE PACKAGE BODY test_api_pkg_clientes AS

    -- Documentos válidos que não estão na carga de exemplo.
    c_cpf_base CONSTANT VARCHAR2(14) := '390.533.447-05';
    g_id       api_pkg_clientes.t_id;

    PROCEDURE criar_cliente_base IS
    BEGIN
        g_id := api_pkg_clientes.criar('Cliente Base de Teste', c_cpf_base, 'SP', 'base@teste.example', 1000);
    END criar_cliente_base;

    -- Criação ---------------------------------------------------------------
    PROCEDURE documento_normalizado IS
        v_cliente api_pkg_clientes.t_cliente := api_pkg_clientes.obter(g_id);
    BEGIN
        ut.expect(v_cliente.documento).to_equal('39053344705');
        ut.expect(v_cliente.tipo_pessoa).to_equal('F');
        ut.expect(v_cliente.versao).to_equal(1);
    END documento_normalizado;

    PROCEDURE campos_normalizados IS
        v_id      api_pkg_clientes.t_id;
        v_cliente api_pkg_clientes.t_cliente;
    BEGIN
        v_id := api_pkg_clientes.criar('  Loja   Teste  ', '98765432100', ' go ', ' Loja@Teste.EXAMPLE ');
        v_cliente := api_pkg_clientes.obter(v_id);
        ut.expect(v_cliente.nome).to_equal('Loja Teste');
        ut.expect(v_cliente.uf).to_equal('GO');
        ut.expect(v_cliente.email).to_equal('loja@teste.example');
        ut.expect(v_cliente.limite_credito).to_equal(0);
    END campos_normalizados;

    PROCEDURE cnpj_alfanumerico IS
        v_id api_pkg_clientes.t_id;
    BEGIN
        -- O 12.ABC.345/01DE-35 já está na carga; este é outro, gerado com o mesmo cálculo.
        v_id := api_pkg_clientes.criar('Empresa Teste', '11.222.333/0002-62', 'MG');
        ut.expect(api_pkg_clientes.obter(v_id).tipo_pessoa).to_equal('J');
        ut.expect(api_pkg_clientes.documento_valido('12.abc.345/01de-35')).to_be_true();
    END cnpj_alfanumerico;

    -- Validação -------------------------------------------------------------
    PROCEDURE nome_em_branco IS
        v_id api_pkg_clientes.t_id;
    BEGIN
        v_id := api_pkg_clientes.criar('   ', '98765432100', 'SP');
    END nome_em_branco;

    PROCEDURE cpf_invalido IS
        v_id api_pkg_clientes.t_id;
    BEGIN
        v_id := api_pkg_clientes.criar('Cliente', '987.654.321-01', 'SP');
    END cpf_invalido;

    PROCEDURE documento_duplicado IS
        v_id api_pkg_clientes.t_id;
    BEGIN
        v_id := api_pkg_clientes.criar('Outro nome', '39053344705', 'RJ');
    END documento_duplicado;

    PROCEDURE email_invalido IS
        v_id api_pkg_clientes.t_id;
    BEGIN
        v_id := api_pkg_clientes.criar('Cliente', '98765432100', 'SP', 'cliente@semdominio');
    END email_invalido;

    PROCEDURE uf_invalida IS
        v_id api_pkg_clientes.t_id;
    BEGIN
        v_id := api_pkg_clientes.criar('Cliente', '98765432100', 'XX');
    END uf_invalida;

    PROCEDURE limite_negativo IS
        v_id api_pkg_clientes.t_id;
    BEGIN
        v_id := api_pkg_clientes.criar('Cliente', '98765432100', 'SP', NULL, -0.01);
    END limite_negativo;

    PROCEDURE funcao_documento_valido IS
    BEGIN
        ut.expect(api_pkg_clientes.documento_valido('111.444.777-35')).to_be_true();
        ut.expect(api_pkg_clientes.documento_valido('111.444.777-36')).to_be_false();
        ut.expect(api_pkg_clientes.documento_valido('000.000.000-00')).to_be_false();
        ut.expect(api_pkg_clientes.documento_valido(NULL)).to_be_false();
    END funcao_documento_valido;

    -- Concorrência ----------------------------------------------------------
    PROCEDURE alterar_soma_versao IS
        v_cliente api_pkg_clientes.t_cliente;
    BEGIN
        api_pkg_clientes.alterar(g_id, 1, 'Cliente Base Alterado', 'SP', NULL, 2000);
        v_cliente := api_pkg_clientes.obter(g_id);
        ut.expect(v_cliente.versao).to_equal(2);
        ut.expect(v_cliente.nome).to_equal('Cliente Base Alterado');
        ut.expect(v_cliente.email).to_be_null();
        ut.expect(v_cliente.alterado_em).not_to_be_null();
    END alterar_soma_versao;

    PROCEDURE versao_velha IS
    BEGIN
        -- Duas telas leram a versão 1; a primeira salva, a segunda recebe o erro.
        api_pkg_clientes.alterar(g_id, 1, 'Primeira tela', 'SP', NULL, 1000);
        api_pkg_clientes.alterar(g_id, 1, 'Segunda tela',  'SP', NULL, 1000);
    END versao_velha;

    PROCEDURE alterar_inativo IS
    BEGIN
        api_pkg_clientes.inativar(g_id, 1);
        api_pkg_clientes.alterar(g_id, 2, 'Cliente', 'SP', NULL, 0);
    END alterar_inativo;

    PROCEDURE alterar_inexistente IS
    BEGIN
        api_pkg_clientes.alterar(-1, 1, 'Cliente', 'SP', NULL, 0);
    END alterar_inexistente;

    -- Consulta --------------------------------------------------------------
    PROCEDURE listar_igual_consulta IS
        v_atual    SYS_REFCURSOR;
        v_esperado SYS_REFCURSOR;
    BEGIN
        v_atual := api_pkg_clientes.listar(p_uf => 'sp', p_nome_contem => 'base de teste');
        OPEN v_esperado FOR
            SELECT id_cliente, nome, uf, ativo, versao
              FROM api_clientes
             WHERE id_cliente = g_id;
        ut.expect(v_atual).to_equal(v_esperado);
    END listar_igual_consulta;

    PROCEDURE porcentagem_literal IS
    BEGIN
        ut.expect(api_pkg_clientes.listar(p_nome_contem => '%')).to_be_empty();
    END porcentagem_literal;

    PROCEDURE pagina_grande IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        v_cursor := api_pkg_clientes.listar(p_tamanho => 101);
    END pagina_grande;

    PROCEDURE json_do_cliente IS
        v_json VARCHAR2(4000) := api_pkg_clientes.obter_json(g_id);
    BEGIN
        ut.expect(JSON_VALUE(v_json, '$.ativo')).to_equal('true');
        ut.expect(JSON_VALUE(v_json, '$.email')).to_equal('base@teste.example');
        ut.expect(JSON_VALUE(v_json, '$.documento')).to_equal('39053344705');
    END json_do_cliente;

END test_api_pkg_clientes;
/

SHOW ERRORS PACKAGE BODY test_api_pkg_clientes

SET SERVEROUTPUT ON SIZE UNLIMITED

-- Roda a suite. Esperado no fim do relatório:
--   Finished in ... seconds
--   18 tests, 0 failed, 0 errored, 0 disabled, 0 warning(s)
EXEC ut.run('test_api_pkg_clientes')
