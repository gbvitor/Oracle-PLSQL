-- =============================================================================
-- Tópico : Data Pump — exportar o próprio schema por PL/SQL (DBMS_DATAPUMP),
--          acompanhar o job, linhas de comando de expdp e impdp
-- Seção  : 13-administracao
-- Versão : 19c
-- Requer : Parte 1 [DBA]: um DIRECTORY com acesso para o usuário de estudo.
--          Parte 2 como o usuário de estudo. Não funciona no FreeSQL.
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- -----------------------------------------------------------------------------
-- Parte 1 [DBA]: pasta no servidor e permissão.
-- No container Free, /opt/oracle/admin/FREE/dpdump existe; ou crie outra pasta
-- (docker exec -it <container> mkdir -p /opt/oracle/dpdump_estudo).
-- -----------------------------------------------------------------------------
--   CREATE OR REPLACE DIRECTORY tmp_dp_dir AS '/opt/oracle/dpdump_estudo';
--   GRANT READ, WRITE ON DIRECTORY tmp_dp_dir TO estudo;

-- -----------------------------------------------------------------------------
-- Parte 2 [ESTUDO]: exportação do próprio schema por PL/SQL.
-- -----------------------------------------------------------------------------

-- Esperado: TMP_DP_DIR | caminho no servidor
SELECT directory_name, directory_path FROM all_directories WHERE directory_name = 'TMP_DP_DIR';

DECLARE
    v_handle NUMBER;
    v_estado VARCHAR2(30);
    v_scn    NUMBER;
BEGIN
    v_handle := DBMS_DATAPUMP.OPEN(operation => 'EXPORT', job_mode => 'SCHEMA', job_name => 'TMP_EXP_ESTUDO');

    DBMS_DATAPUMP.ADD_FILE(v_handle, 'tmp_estudo.dmp', 'TMP_DP_DIR',
                           reusefile => 1);
    DBMS_DATAPUMP.ADD_FILE(v_handle, 'tmp_estudo_exp.log', 'TMP_DP_DIR',
                           filetype => DBMS_DATAPUMP.KU$_FILE_TYPE_LOG_FILE, reusefile => 1);

    -- Só o próprio schema, sem as tabelas de teste.
    DBMS_DATAPUMP.METADATA_FILTER(v_handle, 'SCHEMA_EXPR', 'IN (''ESTUDO'')');
    DBMS_DATAPUMP.METADATA_FILTER(v_handle, 'NAME_EXPR', 'NOT LIKE ''TMP%''', 'TABLE');

    -- Consistência: todas as tabelas no mesmo instante (o SCN atual).
    SELECT current_scn INTO v_scn FROM v$database;
    DBMS_DATAPUMP.SET_PARAMETER(v_handle, 'FLASHBACK_SCN', v_scn);

    DBMS_DATAPUMP.START_JOB(v_handle);
    DBMS_DATAPUMP.WAIT_FOR_JOB(v_handle, v_estado);

    DBMS_OUTPUT.PUT_LINE('Estado final: ' || v_estado);
END;
/
-- Esperado: Estado final: COMPLETED
--           e, no servidor, tmp_estudo.dmp e tmp_estudo_exp.log na pasta do DIRECTORY.
--           O log lista as 7 tabelas com o número de linhas exportadas
--           (ITENS_PEDIDO 54, PEDIDOS 24, PRODUTOS 15, FUNCIONARIOS 14, CLIENTES 12,
--            CATEGORIAS 7, DEPARTAMENTOS 5)

-- Jobs de Data Pump do usuário (vazio depois de terminar; mostra os que estão rodando
-- ou parados).
SELECT job_name, operation, job_mode, state FROM user_datapump_jobs;

-- Ler o log sem acessar o servidor: UTL_FILE no mesmo DIRECTORY.
DECLARE
    v_arq   UTL_FILE.FILE_TYPE;
    v_linha VARCHAR2(4000);
BEGIN
    v_arq := UTL_FILE.FOPEN('TMP_DP_DIR', 'tmp_estudo_exp.log', 'r', 4000);
    LOOP
        BEGIN
            UTL_FILE.GET_LINE(v_arq, v_linha);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                EXIT;
        END;
        DBMS_OUTPUT.PUT_LINE(v_linha);
    END LOOP;
    UTL_FILE.FCLOSE(v_arq);
END;
/
-- Esperado: o mesmo log que o expdp mostraria na tela, terminando em
--           "Job "ESTUDO"."TMP_EXP_ESTUDO" successfully completed at ..."

-- -----------------------------------------------------------------------------
-- Parte 3: as mesmas operações pela linha de comando, no servidor ou numa máquina
-- com o cliente instalado (o arquivo é sempre gravado no servidor).
-- -----------------------------------------------------------------------------
--
-- Exportar com arquivo de parâmetros (tmp_exp.par):
--   schemas=ESTUDO
--   directory=TMP_DP_DIR
--   dumpfile=tmp_estudo_cli.dmp
--   logfile=tmp_estudo_cli_exp.log
--   exclude=TABLE:"LIKE 'TMP%'"
--   flashback_time=SYSTIMESTAMP
--
--   expdp estudo@//localhost:1521/FREEPDB1 parfile=tmp_exp.par
--
-- Só o DDL contido no dump, sem importar nada:
--   impdp estudo@//localhost:1521/FREEPDB1 directory=TMP_DP_DIR dumpfile=tmp_estudo.dmp sqlfile=tmp_estudo_ddl.sql
--   Esperado: tmp_estudo_ddl.sql no DIRECTORY com CREATE TABLE, índices, constraints
--
-- [DBA] Importar como outro schema:
--   impdp system@//localhost:1521/FREEPDB1 directory=TMP_DP_DIR dumpfile=tmp_estudo.dmp
--         remap_schema=ESTUDO:TMP_ESTUDO_COPIA logfile=tmp_estudo_imp.log
--   Esperado: TMP_ESTUDO_COPIA com as 7 tabelas e os dados.
--   Um dump gerado pelo próprio usuário (sem DATAPUMP_EXP_FULL_DATABASE) não contém o
--   CREATE USER: nesse caso, crie TMP_ESTUDO_COPIA antes, com cota no tablespace.
--   Limpeza: DROP USER tmp_estudo_copia CASCADE;
--
-- Acompanhar um job em execução, de outro terminal:
--   expdp estudo@//localhost:1521/FREEPDB1 attach=TMP_EXP_ESTUDO
--   Export> STATUS
--
-- [DBA] Limpeza dos arquivos e do DIRECTORY:
--   EXEC UTL_FILE.FREMOVE('TMP_DP_DIR', 'tmp_estudo.dmp')
--   EXEC UTL_FILE.FREMOVE('TMP_DP_DIR', 'tmp_estudo_exp.log')
--   DROP DIRECTORY tmp_dp_dir;
