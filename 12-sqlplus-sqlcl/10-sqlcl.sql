-- =============================================================================
-- Tópico : SQLcl — SQLFORMAT, DDL, INFO, HISTORY, ALIAS, UNLOAD, LOAD, CTAS
-- Seção  : 12-sqlplus-sqlcl
-- Versão : SQLcl (não roda no SQL*Plus: os comandos próprios dão SP2-0734)
-- Requer : schema de exemplo (00-ambiente)
--
-- O formato exato da saída muda entre versões do SQLcl; os esperados mostram a forma.
-- =============================================================================

-- 1. Formatos de saída.
SET SQLFORMAT csv
SELECT id_departamento, nome, cidade FROM departamentos ORDER BY 1;
-- Esperado:
--   "ID_DEPARTAMENTO","NOME","CIDADE"
--   10,"Diretoria","Sao Paulo"
--   ...

SET SQLFORMAT json
SELECT id_departamento, nome FROM departamentos WHERE id_departamento <= 20 ORDER BY 1;
-- Esperado: {"results":[{"columns":[...],"items":[{"id_departamento":10,"nome":"Diretoria"},...]}]}

SET SQLFORMAT insert
SELECT * FROM departamentos WHERE id_departamento = 50;
-- Esperado: REM INSERTING into DEPARTAMENTOS
--           Insert into DEPARTAMENTOS (ID_DEPARTAMENTO,NOME,CIDADE) values (50,'Marketing',null);
--           (a forma de escrever números e datas varia com a versão)

SET SQLFORMAT ansiconsole
SELECT id_cliente, nome, cidade, limite_credito FROM clientes WHERE uf = 'SP';
-- Esperado: colunas com a largura dos dados e números formatados

-- O mesmo, por comentário na consulta, sem mudar a configuração.
SELECT /*csv*/ id_categoria, nome FROM categorias ORDER BY 1;

SET SQLFORMAT

-- 2. DDL e INFO.
DDL departamentos
-- Esperado: CREATE TABLE "ESTUDO"."DEPARTAMENTOS" ( ... ) com constraints e storage

INFO clientes
-- Esperado: colunas com tipo e NOT NULL, comentários, PK, UK, FKs que apontam para
--           a tabela e índices

INFO+ pedidos
-- Esperado: o mesmo, mais estatísticas: num_rows, último analyze, valores distintos por coluna

-- 3. Histórico.
HISTORY
-- Esperado: lista numerada dos últimos comandos

HISTORY USAGE
-- Esperado: comandos com a quantidade de vezes que foram usados

HISTORY TIME
-- Esperado: comandos com o tempo de execução

-- 4. ALIAS: consulta frequente com nome curto.
ALIAS tmp_invalidos = SELECT object_type, object_name FROM user_objects WHERE status = 'INVALID' ORDER BY 1, 2;

tmp_invalidos
-- Esperado: nenhuma linha (ou os objetos inválidos do schema)

ALIAS tmp_pedidos_cliente = SELECT id_pedido, status FROM pedidos WHERE id_cliente = :id ORDER BY id_pedido;

tmp_pedidos_cliente 8
-- Esperado: 1007 CANCELADO | 1018 ENTREGUE (o argumento vai para o bind :id)

ALIAS LIST
ALIAS DROP tmp_invalidos
ALIAS DROP tmp_pedidos_cliente

-- 5. UNLOAD e LOAD: tabela para CSV e CSV para tabela.
SET SQLFORMAT csv
SET LOADFORMAT csv
UNLOAD departamentos
-- Esperado: arquivo DEPARTAMENTOS_DATA_TABLE.csv no diretório atual
--           (o nome gerado pode variar com a versão; a mensagem informa)

CTAS departamentos tmp_departamentos_copia
-- Esperado: o texto de um CREATE TABLE tmp_departamentos_copia AS SELECT ..., para
--           revisar e executar. Aqui, a cópia vazia é criada direto:
CREATE TABLE tmp_departamentos_copia AS SELECT * FROM departamentos WHERE 1 = 0;

-- Carregar o arquivo gerado pelo UNLOAD (troque o nome pelo que foi informado acima).
LOAD tmp_departamentos_copia DEPARTAMENTOS_DATA_TABLE.csv
-- Esperado: "#INFO Number of rows processed: 5" e nenhum erro

-- Esperado: 5
SELECT COUNT(*) FROM tmp_departamentos_copia;

DROP TABLE tmp_departamentos_copia PURGE;
SET SQLFORMAT

-- 6. REPEAT: acompanhar uma consulta (aqui, 3 vezes a cada 2 segundos).
SELECT COUNT(*) AS sessoes FROM v$session WHERE username = USER;
REPEAT 3 2
-- Esperado: a consulta reexecutada três vezes, com data e hora em cada uma

-- 7. Formatar SQL.
SELECT p.id_pedido,c.nome FROM pedidos p JOIN clientes c ON c.id_cliente=p.id_cliente WHERE p.status='ABERTO';
FORMAT BUFFER
-- Esperado: o último comando reescrito com quebras de linha e recuo

-- 8. Liquibase (rode numa pasta vazia; gera vários arquivos).
--   lb help
--   lb generate-schema
-- Esperado: changelogs XML do schema e um controller.xml que os agrupa
