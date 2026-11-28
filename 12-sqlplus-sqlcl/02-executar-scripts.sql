-- =============================================================================
-- Tópico : Executar scripts — @@ com parâmetro, script mestre, PROMPT
-- Seção  : 12-sqlplus-sqlcl
-- Versão : 19c (SQL*Plus ou SQLcl)
-- Requer : schema de exemplo (00-ambiente); 02-relatorio-cliente.sql na mesma pasta
--
-- Rode a partir de qualquer diretório: @caminho/12-sqlplus-sqlcl/02-executar-scripts.sql
-- O @@ encontra o script filho na pasta deste arquivo.
-- =============================================================================

PROMPT === Script mestre: relatório de dois clientes ===

-- 1. Chamar o script filho com parâmetro.
@@02-relatorio-cliente.sql 3
-- Esperado:
--   Cliente 3
--   Escritorio Modelo SA  Belo Horizonte  MG
--   1002 ENTREGUE 16.276,50 | 1009 ENTREGUE 5.163,44 | 1017 ENTREGUE 7.554,28
--   (o separador de milhar e decimal segue o NLS da sessão)

@@02-relatorio-cliente.sql 8
-- Esperado:
--   Cliente 8
--   Clinica Bem Estar Ltda  Salvador  BA
--   1007 CANCELADO 1.798,00 | 1018 ENTREGUE 1.507,70

-- 2. Parâmetro com espaço vai entre aspas na chamada.
--    (o filho atual espera um número; o exemplo só mostra a forma)
--   @@outro-script.sql 'Belo Horizonte' MG

PROMPT === Fim ===

-- 3. Em automação, o script termina com EXIT (aqui fica comentado para não fechar
--    a sessão de estudo):
--   EXIT
