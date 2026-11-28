-- =============================================================================
-- Tópico : Pacotes nativos — DBMS_OUTPUT, DBMS_SESSION.SLEEP,
--          DBMS_APPLICATION_INFO, DBMS_LOB, UTL_FILE, DBMS_RANDOM
-- Seção  : 09-plsql-avancado
-- Versão : 19c (DBMS_SESSION.SLEEP exige 18c+)
-- Requer : schema de exemplo (00-ambiente); passo 5 exige um DIRECTORY criado
--          pelo DBA (não funciona no FreeSQL)
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- 1. DBMS_OUTPUT: PUT, NEW_LINE e leitura do próprio buffer com GET_LINES.
DECLARE
    v_linhas DBMS_OUTPUT.CHARARR;
    v_qtd    INTEGER := 100;
BEGIN
    DBMS_OUTPUT.PUT('montada ');
    DBMS_OUTPUT.PUT('em ');
    DBMS_OUTPUT.PUT('partes');
    DBMS_OUTPUT.NEW_LINE;
    DBMS_OUTPUT.PUT_LINE('segunda linha');

    -- Tira as linhas do buffer (o SQL*Plus não verá estas duas).
    DBMS_OUTPUT.GET_LINES(v_linhas, v_qtd);

    DBMS_OUTPUT.PUT_LINE('Capturadas ' || v_qtd || ' linhas:');
    FOR i IN 1 .. v_qtd LOOP
        DBMS_OUTPUT.PUT_LINE('  [' || v_linhas(i) || ']');
    END LOOP;
END;
/
-- Esperado: Capturadas 2 linhas: | [montada em partes] | [segunda linha]

-- 2. [18c+] Pausa sem grant especial.
DECLARE
    v_inicio PLS_INTEGER := DBMS_UTILITY.GET_TIME;
BEGIN
    DBMS_SESSION.SLEEP(1.5);
    DBMS_OUTPUT.PUT_LINE('Esperou ' || (DBMS_UTILITY.GET_TIME - v_inicio) / 100 || ' s');
END;
/
-- Esperado: Esperou 1.5 s (ou 1.51, 1.52: GET_TIME tem resolução de centésimos)

-- 3. DBMS_APPLICATION_INFO: identificar o que a sessão está fazendo.
BEGIN
    DBMS_APPLICATION_INFO.SET_MODULE(module_name => 'tmp_carga_pedidos', action_name => 'inicio');
    DBMS_APPLICATION_INFO.SET_ACTION('lote 1 de 3');
    DBMS_APPLICATION_INFO.SET_CLIENT_INFO('executado pelo repositório de estudo');
END;
/

-- Esperado: tmp_carga_pedidos | lote 1 de 3 | executado pelo repositório de estudo
SELECT SYS_CONTEXT('USERENV', 'MODULE')      AS modulo,
       SYS_CONTEXT('USERENV', 'ACTION')      AS acao,
       SYS_CONTEXT('USERENV', 'CLIENT_INFO') AS info
  FROM dual;

-- O mesmo, visto pelo DBA em V$SESSION.
SELECT sid, module, action, client_info
  FROM v$session
 WHERE sid = SYS_CONTEXT('USERENV', 'SID');

-- Limpar ao terminar.
EXEC DBMS_APPLICATION_INFO.SET_MODULE(NULL, NULL)
EXEC DBMS_APPLICATION_INFO.SET_CLIENT_INFO(NULL)

-- 4. DBMS_LOB: montar um CSV em CLOB.
DECLARE
    v_csv    CLOB;
    v_buffer VARCHAR2(32767);

    PROCEDURE descarregar IS
    BEGIN
        IF v_buffer IS NOT NULL THEN
            DBMS_LOB.WRITEAPPEND(v_csv, LENGTH(v_buffer), v_buffer);
            v_buffer := NULL;
        END IF;
    END;

    PROCEDURE escrever (p_linha IN VARCHAR2) IS
    BEGIN
        IF NVL(LENGTH(v_buffer), 0) + LENGTH(p_linha) + 1 > 32000 THEN
            descarregar;
        END IF;
        v_buffer := v_buffer || p_linha || CHR(10);
    END;
BEGIN
    DBMS_LOB.CREATETEMPORARY(v_csv, TRUE);

    escrever('id_pedido;id_cliente;status;valor');
    FOR r IN (SELECT p.id_pedido, p.id_cliente, p.status,
                     SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
                FROM pedidos p
                JOIN itens_pedido i ON i.id_pedido = p.id_pedido
               GROUP BY p.id_pedido, p.id_cliente, p.status
               ORDER BY p.id_pedido)
    LOOP
        escrever(r.id_pedido || ';' || r.id_cliente || ';' || r.status || ';'
                 || TO_CHAR(r.valor, 'FM999999990D00', 'NLS_NUMERIC_CHARACTERS = '',.'''));
    END LOOP;
    descarregar;

    DBMS_OUTPUT.PUT_LINE('Linhas:   ' || REGEXP_COUNT(v_csv, CHR(10)));
    DBMS_OUTPUT.PUT_LINE('Tamanho:  ' || DBMS_LOB.GETLENGTH(v_csv) || ' caracteres');
    DBMS_OUTPUT.PUT_LINE('Início:   ' || DBMS_LOB.SUBSTR(v_csv, 34, 1));
    DBMS_OUTPUT.PUT_LINE('Posição de "1008;": ' || DBMS_LOB.INSTR(v_csv, '1008;'));

    DBMS_LOB.FREETEMPORARY(v_csv);
END;
/
-- Esperado:
--   Linhas:   25 (cabeçalho + 24 pedidos)
--   Tamanho:  606 caracteres
--   Início:   id_pedido;id_cliente;status;valor
--   Posição de "1008;": 204

-- 5. UTL_FILE: gravar e ler um arquivo no servidor.
--    [DBA] antes, uma vez (pasta do servidor, por exemplo /tmp no container):
--      CREATE OR REPLACE DIRECTORY tmp_dir AS '/tmp';
--      GRANT READ, WRITE ON DIRECTORY tmp_dir TO estudo;
DECLARE
    v_arq   UTL_FILE.FILE_TYPE;
    v_linha VARCHAR2(4000);
    v_qtd   PLS_INTEGER := 0;
BEGIN
    v_arq := UTL_FILE.FOPEN('TMP_DIR', 'tmp_clientes_sp.csv', 'w', 32767);
    UTL_FILE.PUT_LINE(v_arq, 'id;nome');
    FOR r IN (SELECT id_cliente, nome FROM clientes WHERE uf = 'SP' ORDER BY id_cliente) LOOP
        UTL_FILE.PUT_LINE(v_arq, r.id_cliente || ';' || r.nome);
    END LOOP;
    UTL_FILE.FCLOSE(v_arq);

    v_arq := UTL_FILE.FOPEN('TMP_DIR', 'tmp_clientes_sp.csv', 'r', 32767);
    LOOP
        BEGIN
            UTL_FILE.GET_LINE(v_arq, v_linha);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                EXIT;
        END;
        v_qtd := v_qtd + 1;
        DBMS_OUTPUT.PUT_LINE(v_linha);
    END LOOP;
    UTL_FILE.FCLOSE(v_arq);

    DBMS_OUTPUT.PUT_LINE('Lidas: ' || v_qtd);

    UTL_FILE.FREMOVE('TMP_DIR', 'tmp_clientes_sp.csv');
EXCEPTION
    WHEN OTHERS THEN
        IF UTL_FILE.IS_OPEN(v_arq) THEN
            UTL_FILE.FCLOSE(v_arq);
        END IF;
        RAISE;
END;
/
-- Esperado:
--   id;nome
--   1;Papelaria Central Ltda
--   2;Tech Solucoes ME
--   9;Fernanda Araujo
--   Lidas: 4
--   Sem o DIRECTORY: ORA-29280 (caminho de diretório inválido)

-- 6. DBMS_RANDOM: a mesma semente repete a sequência.
DECLARE
    v_a VARCHAR2(200);
    v_b VARCHAR2(200);
BEGIN
    DBMS_RANDOM.SEED(42);
    FOR i IN 1 .. 5 LOOP
        v_a := v_a || TRUNC(DBMS_RANDOM.VALUE(1, 100)) || ' ';
    END LOOP;

    DBMS_RANDOM.SEED(42);
    FOR i IN 1 .. 5 LOOP
        v_b := v_b || TRUNC(DBMS_RANDOM.VALUE(1, 100)) || ' ';
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Sequência A: ' || v_a);
    DBMS_OUTPUT.PUT_LINE('Sequência B: ' || v_b);
    DBMS_OUTPUT.PUT_LINE(CASE WHEN v_a = v_b THEN 'Iguais' ELSE 'Diferentes' END);
    DBMS_OUTPUT.PUT_LINE('Texto aleatório (maiúsculas, 8): ' || DBMS_RANDOM.STRING('U', 8));
END;
/
-- Esperado: duas sequências iguais de 5 números entre 1 e 99, "Iguais",
--           e um texto de 8 letras maiúsculas (os valores dependem da versão)
