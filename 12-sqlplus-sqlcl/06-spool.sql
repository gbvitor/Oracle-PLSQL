-- =============================================================================
-- Tópico : SPOOL — CSV com MARKUP, CSV clássico, relatório texto, nome com data
-- Seção  : 12-sqlplus-sqlcl
-- Versão : 19c (SET MARKUP CSV exige 12.2+)
-- Requer : schema de exemplo (00-ambiente); rodar como script (@06-spool.sql),
--          para o TERMOUT OFF funcionar
--
-- Os arquivos são gravados no diretório atual do SQL*Plus (na sua máquina).
-- Nomes: tmp_departamentos.csv, tmp_pedidos_AAAAMMDD.csv, tmp_relatorio.txt
-- =============================================================================

-- 1. CSV com SET MARKUP CSV.
SET FEEDBACK OFF
SET MARKUP CSV ON DELIMITER ; QUOTE ON

SPOOL tmp_departamentos.csv
SELECT id_departamento, nome, cidade FROM departamentos ORDER BY id_departamento;
SPOOL OFF

SET MARKUP CSV OFF
SET FEEDBACK ON
-- Esperado no arquivo:
--   "ID_DEPARTAMENTO";"NOME";"CIDADE"
--   10;"Diretoria";"Sao Paulo"
--   20;"Comercial";"Sao Paulo"
--   30;"Financeiro";"Belo Horizonte"
--   40;"Logistica";"Goiania"
--   50;"Marketing";

-- 2. CSV clássico, com nome de arquivo datado e valores com vírgula decimal.
COLUMN hoje NEW_VALUE v_hoje NOPRINT
SELECT TO_CHAR(SYSDATE, 'YYYYMMDD') AS hoje FROM dual;

SET PAGESIZE 0
SET FEEDBACK OFF
SET HEADING OFF
SET LINESIZE 32767
SET TRIMSPOOL ON
SET VERIFY OFF
SET ECHO OFF
SET TERMOUT OFF

SPOOL tmp_pedidos_&v_hoje..csv

SELECT 'id_pedido;data;cliente;status;valor' FROM dual;

SELECT p.id_pedido
       || ';' || TO_CHAR(p.data_pedido, 'DD/MM/YYYY')
       || ';' || c.nome
       || ';' || p.status
       || ';' || TO_CHAR(SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)),
                         'FM999999990D00', 'NLS_NUMERIC_CHARACTERS = '',.''')
  FROM pedidos p
  JOIN clientes c     ON c.id_cliente = p.id_cliente
  JOIN itens_pedido i ON i.id_pedido = p.id_pedido
 GROUP BY p.id_pedido, p.data_pedido, c.nome, p.status
 ORDER BY p.id_pedido;

SPOOL OFF

SET TERMOUT ON
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 14
SET LINESIZE 80
-- Esperado: arquivo tmp_pedidos_<data>.csv com 25 linhas:
--   id_pedido;data;cliente;status;valor
--   1001;08/01/2025;Papelaria Central Ltda;ENTREGUE;1045,50
--   1002;15/01/2025;Escritorio Modelo SA;ENTREGUE;16276,50
--   ...
--   1024;30/10/2026;Colegio Saber Ltda;ABERTO;3150,00
--   e nada na tela durante a gravação

PROMPT Gravado: tmp_pedidos_&v_hoje..csv

-- 3. Relatório texto com título, quebra e total.
SET LINESIZE 70
SET PAGESIZE 60
SET FEEDBACK OFF
COLUMN status FORMAT A10 HEADING 'Status'
COLUMN qtd    FORMAT 990 HEADING 'Pedidos'
COLUMN valor  FORMAT 999G990D00 HEADING 'Valor'
TTITLE CENTER 'Pedidos por status' SKIP 1 CENTER 'gerado em &v_hoje' SKIP 2
BREAK ON REPORT
COMPUTE SUM LABEL 'Total' OF qtd valor ON REPORT

SPOOL tmp_relatorio.txt

SELECT p.status,
       COUNT(DISTINCT p.id_pedido) AS qtd,
       SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
  FROM pedidos p
  JOIN itens_pedido i ON i.id_pedido = p.id_pedido
 GROUP BY p.status
 ORDER BY p.status;

SPOOL OFF
-- Esperado no arquivo, além do título:
--   ABERTO        3    5.562,00
--   CANCELADO     1    1.798,00
--   ENTREGUE     17   94.376,21
--   FATURADO      3   21.079,22
--   Total        24  122.815,43

TTITLE OFF
CLEAR BREAKS
CLEAR COMPUTES
CLEAR COLUMNS
SET FEEDBACK ON
SET LINESIZE 80
SET PAGESIZE 14
UNDEFINE v_hoje

-- 4. Conferir o conteúdo sem sair do SQL*Plus (comando do sistema operacional).
--   Linux:   HOST cat tmp_departamentos.csv
--   Windows: HOST type tmp_departamentos.csv
-- E apagar ao terminar:
--   Linux:   HOST rm tmp_departamentos.csv tmp_pedidos_*.csv tmp_relatorio.txt
--   Windows: HOST del tmp_departamentos.csv tmp_pedidos_*.csv tmp_relatorio.txt
