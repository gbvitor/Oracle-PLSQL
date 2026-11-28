-- =============================================================================
-- Tópico : Tablespaces e cotas — onde estão meus dados, uso por tablespace,
--          criação tardia de segmento, espaço que não volta, erro de cota
-- Seção  : 13-administracao
-- Versão : 19c
-- Requer : Parte 1 como o usuário de estudo (SELECT_CATALOG_ROLE para DBA_);
--          Parte 2 [DBA] no PDB
-- =============================================================================

SET LINESIZE 200
COLUMN tablespace_name FORMAT A16
COLUMN segment_name    FORMAT A26

-- -----------------------------------------------------------------------------
-- Parte 1: o usuário de estudo.
-- -----------------------------------------------------------------------------

-- 1. Minha cota.
-- Esperado: USERS | bytes usados | max_bytes -1 (ilimitada)
SELECT tablespace_name, ROUND(bytes / 1024 / 1024, 1) AS mb_usados, max_bytes FROM user_ts_quotas;

-- 2. Onde estão meus segmentos.
-- Esperado: USERS | TABLE 7 | INDEX 18 (schema de exemplo)
SELECT tablespace_name, segment_type, COUNT(*) AS segmentos, ROUND(SUM(bytes) / 1024) AS kb
  FROM user_segments
 WHERE segment_name NOT LIKE 'BIN$%'
 GROUP BY tablespace_name, segment_type
 ORDER BY tablespace_name, segment_type;

-- 3. Uso de cada tablespace do PDB (consulta clássica de monitoramento).
-- Esperado: SYSTEM, SYSAUX, UNDOTBS1, USERS com tamanho, usado, livre e % de uso;
--           max_mb mostra até onde o AUTOEXTEND pode crescer
SELECT d.tablespace_name,
       ROUND(d.mb)                               AS tamanho_mb,
       ROUND(d.mb - NVL(f.mb, 0))                AS usado_mb,
       ROUND(NVL(f.mb, 0))                       AS livre_mb,
       ROUND(100 * (d.mb - NVL(f.mb, 0)) / d.mb) AS pct_uso,
       ROUND(d.max_mb)                           AS max_mb
  FROM (SELECT tablespace_name,
               SUM(bytes) / 1048576 AS mb,
               SUM(GREATEST(bytes, DECODE(autoextensible, 'YES', maxbytes, bytes))) / 1048576 AS max_mb
          FROM dba_data_files
         GROUP BY tablespace_name) d
  LEFT JOIN (SELECT tablespace_name, SUM(bytes) / 1048576 AS mb
               FROM dba_free_space
              GROUP BY tablespace_name) f
    ON f.tablespace_name = d.tablespace_name
 ORDER BY pct_uso DESC;

-- Temporário em uso agora (por sessão).
SELECT s.sid, s.username, u.tablespace, u.segtype, u.blocks
  FROM v$tempseg_usage u
  JOIN v$session s ON s.saddr = u.session_addr;

-- 4. Criação tardia de segmento: tabela vazia não ocupa espaço.
CREATE TABLE tmp_espaco (id NUMBER, texto VARCHAR2(200));

-- Esperado: nenhuma linha (o segmento ainda não existe)
SELECT segment_name, bytes FROM user_segments WHERE segment_name = 'TMP_ESPACO';

INSERT INTO tmp_espaco SELECT LEVEL, RPAD('x', 200, 'x') FROM dual CONNECT BY LEVEL <= 20000;
COMMIT;

-- Esperado: TMP_ESPACO com alguns MB
SELECT segment_name, ROUND(bytes / 1024 / 1024, 1) AS mb, extents FROM user_segments WHERE segment_name = 'TMP_ESPACO';

-- 5. DELETE não devolve espaço; MOVE (ou SHRINK) devolve.
DELETE FROM tmp_espaco WHERE id > 1000;
COMMIT;

-- Esperado: o mesmo tamanho de antes do DELETE
SELECT segment_name, ROUND(bytes / 1024 / 1024, 1) AS mb FROM user_segments WHERE segment_name = 'TMP_ESPACO';

ALTER TABLE tmp_espaco MOVE;

-- Esperado: bem menor (só as 1000 linhas restantes)
SELECT segment_name, ROUND(bytes / 1024 / 1024, 2) AS mb FROM user_segments WHERE segment_name = 'TMP_ESPACO';

DROP TABLE tmp_espaco PURGE;

-- -----------------------------------------------------------------------------
-- Parte 2 [DBA]: tablespace e usuário com cota pequena.
-- -----------------------------------------------------------------------------

--   CREATE TABLESPACE tmp_ts_estudo DATAFILE SIZE 20M AUTOEXTEND ON NEXT 10M MAXSIZE 100M;
--   (sem caminho: funciona com OMF, como no container Free; senão, informe o arquivo)
--
--   CREATE USER tmp_cota IDENTIFIED BY "Cota#2026" DEFAULT TABLESPACE tmp_ts_estudo;
--   GRANT CREATE SESSION, CREATE TABLE TO tmp_cota;
--
--   [TMP_COTA] sem cota nenhuma:
--     CREATE TABLE t (x VARCHAR2(200));
--     Esperado: tabela criada (segmento ainda não existe)
--     INSERT INTO t VALUES ('a');
--     Esperado: ORA-01950 (sem privilégios no tablespace TMP_TS_ESTUDO)
--
--   [DBA] ALTER USER tmp_cota QUOTA 1M ON tmp_ts_estudo;
--
--   [TMP_COTA]
--     INSERT INTO t SELECT RPAD('x', 200, 'x') FROM dual CONNECT BY LEVEL <= 100000;
--     Esperado: ORA-01536 (cota de espaço excedida para o tablespace TMP_TS_ESTUDO)
--
--   [DBA] limpeza:
--     DROP USER tmp_cota CASCADE;
--     DROP TABLESPACE tmp_ts_estudo INCLUDING CONTENTS AND DATAFILES;
