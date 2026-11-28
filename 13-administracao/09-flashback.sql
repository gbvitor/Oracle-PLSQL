-- =============================================================================
-- Tópico : Flashback — versões de uma linha, FLASHBACK TABLE TO SCN, lixeira
-- Seção  : 13-administracao
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); leitura de V$DATABASE para o SCN.
--          Rode os passos em sequência, sem pausa longa (o alcance é o do undo).
-- =============================================================================

SET LINESIZE 200
COLUMN versions_operation FORMAT A3 HEADING 'Op'
COLUMN nome               FORMAT A26

-- Tabela de trabalho, com ROW MOVEMENT para o FLASHBACK TABLE.
CREATE TABLE tmp_fb_clientes AS SELECT id_cliente, nome, uf, limite_credito FROM clientes;
ALTER TABLE tmp_fb_clientes ADD CONSTRAINT pk_tmp_fb_clientes PRIMARY KEY (id_cliente);
ALTER TABLE tmp_fb_clientes ENABLE ROW MOVEMENT;

-- 1. Guardar o SCN do "antes" numa variável de ligação.
VARIABLE scn_antes NUMBER
BEGIN
    SELECT current_scn INTO :scn_antes FROM v$database;
END;
/
PRINT scn_antes

-- 2. Mudanças "erradas", confirmadas.
UPDATE tmp_fb_clientes SET limite_credito = limite_credito * 1.1 WHERE uf = 'SP';
COMMIT;

DELETE FROM tmp_fb_clientes WHERE id_cliente = 12;
COMMIT;

UPDATE tmp_fb_clientes SET limite_credito = 60000 WHERE id_cliente = 1;
COMMIT;

-- Esperado: 1 60000 | 2 33000 | 9 4400 e 11 linhas (o 12 foi excluído)
SELECT id_cliente, limite_credito FROM tmp_fb_clientes WHERE uf = 'SP' ORDER BY id_cliente;
SELECT COUNT(*) FROM tmp_fb_clientes;

-- 3. Versões de cada linha desde o SCN guardado.
-- Esperado para o cliente 1 (da mais antiga para a atual):
--   Op (vazio) | start vazio | 50000   (a versão original, já existente antes do intervalo)
--   U          | scn do 1o UPDATE | 55000
--   U          | scn do 3o UPDATE | 60000 | end vazio (é a atual)
SELECT versions_startscn, versions_endscn, versions_operation, versions_xid, limite_credito
  FROM tmp_fb_clientes VERSIONS BETWEEN SCN :scn_antes AND MAXVALUE
 WHERE id_cliente = 1
 ORDER BY versions_startscn NULLS FIRST;

-- Esperado para o cliente 12: a versão original e uma versão D (a exclusão)
SELECT versions_startscn, versions_endscn, versions_operation, nome, limite_credito
  FROM tmp_fb_clientes VERSIONS BETWEEN SCN :scn_antes AND MAXVALUE
 WHERE id_cliente = 12
 ORDER BY versions_startscn NULLS FIRST;

-- Todas as mudanças do período, por transação.
-- Esperado: três transações: uma com 3 U (os clientes de SP), uma com 1 D, uma com 1 U
SELECT versions_xid, versions_operation, COUNT(*) AS linhas
  FROM tmp_fb_clientes VERSIONS BETWEEN SCN :scn_antes AND MAXVALUE
 WHERE versions_xid IS NOT NULL
 GROUP BY versions_xid, versions_operation
 ORDER BY MIN(versions_startscn);

-- 4. Correção cirúrgica (só o cliente 12 de volta), sem mexer no resto.
INSERT INTO tmp_fb_clientes
SELECT * FROM tmp_fb_clientes AS OF SCN :scn_antes WHERE id_cliente = 12;

-- Esperado: 12 linhas; os limites de SP continuam alterados
SELECT COUNT(*) FROM tmp_fb_clientes;
ROLLBACK;

-- 5. Voltar a tabela inteira ao SCN guardado.
FLASHBACK TABLE tmp_fb_clientes TO SCN :scn_antes;

-- Esperado: 12 linhas e os limites originais: 1 50000 | 2 30000 | 9 4000
SELECT COUNT(*) FROM tmp_fb_clientes;
SELECT id_cliente, limite_credito FROM tmp_fb_clientes WHERE uf = 'SP' ORDER BY id_cliente;

-- Sem ROW MOVEMENT, o FLASHBACK TABLE recusa.
ALTER TABLE tmp_fb_clientes DISABLE ROW MOVEMENT;
-- Esperado: ORA-08189 (não é possível fazer flashback da tabela porque a movimentação de linha não está ativada)
FLASHBACK TABLE tmp_fb_clientes TO SCN :scn_antes;

-- 6. A lixeira.
DROP TABLE tmp_fb_clientes;

-- Esperado: TMP_FB_CLIENTES com nome BIN$... e o índice da PK também na lixeira
COLUMN original_name FORMAT A22
COLUMN object_name   FORMAT A32
SELECT original_name, object_name, type, droptime FROM user_recyclebin ORDER BY droptime;

FLASHBACK TABLE tmp_fb_clientes TO BEFORE DROP;

-- Esperado: 12 linhas; o índice voltou com nome BIN$... (renomeie se for continuar usando)
SELECT COUNT(*) FROM tmp_fb_clientes;
SELECT index_name FROM user_indexes WHERE table_name = 'TMP_FB_CLIENTES';

-- 7. Alcance: retenção de undo.
-- Esperado: undo_retention 900 (segundos) no padrão
SELECT name, value FROM v$parameter WHERE name = 'undo_retention';

-- O SCN de 15 minutos atrás: com o undo padrão e espaço suficiente, é até perto dele
-- que as consultas AS OF e o FLASHBACK TABLE costumam alcançar.
SELECT TIMESTAMP_TO_SCN(SYSTIMESTAMP - INTERVAL '15' MINUTE) AS scn_15_min_atras FROM dual;

DROP TABLE tmp_fb_clientes PURGE;
