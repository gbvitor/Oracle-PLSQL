-- =============================================================================
-- Tópico : Formatação — página, COLUMN, NULL, BREAK, COMPUTE, TTITLE, MARKUP
-- Seção  : 12-sqlplus-sqlcl
-- Versão : 19c (SQL*Plus; quase tudo funciona também no SQLcl)
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Sem formatação: largura e quebras padrão.
SELECT id_cliente, nome, email, cidade, limite_credito FROM clientes WHERE id_cliente <= 3;
-- Esperado: linhas quebradas ou colunas largas demais, conforme o terminal

-- 2. Página, linha e colunas.
SET LINESIZE 160
SET PAGESIZE 100
SET FEEDBACK OFF
SET NULL '(nulo)'

COLUMN id_cliente     FORMAT 999            HEADING 'Id'
COLUMN nome           FORMAT A26            HEADING 'Cliente'
COLUMN email          FORMAT A32            HEADING 'E-mail'
COLUMN cidade         FORMAT A16
COLUMN limite_credito FORMAT 999G999G990D00 HEADING 'Limite|de crédito'

SELECT id_cliente, nome, email, cidade, limite_credito FROM clientes WHERE id_cliente <= 3;
-- Esperado:
--    Id Cliente                    E-mail                           CIDADE              Limite
--                                                                                   de crédito
--   --- -------------------------- -------------------------------- ---------------- -----------
--     1 Papelaria Central Ltda     contato@papelariacentral.example Sao Paulo         50.000,00
--     2 Tech Solucoes ME           compras@techsolucoes.example     Campinas          30.000,00
--     3 Escritorio Modelo SA       (nulo)                           Belo Horizonte    80.000,00
--   (separadores conforme o NLS; com NLS americano, 50,000.00)

-- 3. Número maior que o formato.
COLUMN limite_credito FORMAT 9G990D00
SELECT nome, limite_credito FROM clientes WHERE id_cliente IN (1, 4);
-- Esperado: ##### no cliente 1 (50000 não cabe em 9.990,00); 5.000,00 no cliente 4
COLUMN limite_credito FORMAT 999G999G990D00 HEADING 'Limite|de crédito'

-- 4. Texto longo: quebra por palavra.
COLUMN observacao FORMAT A14 WORD_WRAPPED
SELECT id_pedido, observacao FROM pedidos WHERE observacao IS NOT NULL ORDER BY id_pedido;
-- Esperado: "Entregar no 3o andar", "Pedido feito pelo site" etc. quebrados em duas linhas
COLUMN observacao CLEAR

-- 5. BREAK e COMPUTE: subtotal por cliente e total geral.
COLUMN cliente FORMAT A26
COLUMN valor   FORMAT 999G990D00

BREAK ON cliente SKIP 1 ON REPORT
COMPUTE SUM LABEL 'Subtotal' OF valor ON cliente
COMPUTE SUM LABEL 'Total'    OF valor ON REPORT

SELECT c.nome AS cliente,
       p.id_pedido,
       p.status,
       SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS valor
  FROM clientes c
  JOIN pedidos p      ON p.id_cliente = c.id_cliente
  JOIN itens_pedido i ON i.id_pedido = p.id_pedido
 WHERE c.id_cliente IN (1, 3)
 GROUP BY c.nome, p.id_pedido, p.status
 ORDER BY c.nome, p.id_pedido;
-- Esperado:
--   Escritorio Modelo SA        1002 ENTREGUE   16.276,50
--                               1009 ENTREGUE    5.163,44
--                               1017 ENTREGUE    7.554,28
--   **************************                 ----------
--   Subtotal                                    28.994,22
--
--   Papelaria Central Ltda      1001 ENTREGUE    1.045,50
--                               1006 ENTREGUE    2.046,00
--                               1015 ENTREGUE    1.311,50
--                               1022 ABERTO      1.513,00
--   **************************                 ----------
--   Subtotal                                     5.916,00
--
--                                              ----------
--   Total                                       34.910,22

CLEAR BREAKS
CLEAR COMPUTES

-- 6. Título de página com número.
TTITLE LEFT 'Clientes ativos' RIGHT 'Página ' FORMAT 99 SQL.PNO SKIP 2
SELECT id_cliente, nome, uf FROM clientes WHERE ativo = 'S' ORDER BY id_cliente;
-- Esperado: o título acima do cabeçalho, com "Página 1"
TTITLE OFF

-- 7. HTML e CSV (antes, devolver o NULL ao padrão para o CSV sair com campo vazio).
SET NULL ''

SET MARKUP HTML ON
SELECT id_departamento, nome FROM departamentos ORDER BY 1;
SET MARKUP HTML OFF
-- Esperado: a saída em <table>...</table>

SET MARKUP CSV ON
SELECT id_departamento, nome, cidade FROM departamentos ORDER BY 1;
SET MARKUP CSV OFF
-- Esperado [12.2+]:
--   "ID_DEPARTAMENTO","NOME","CIDADE"
--   10,"Diretoria","Sao Paulo"
--   ...
--   50,"Marketing",

-- 8. Voltar ao padrão.
CLEAR COLUMNS
SET FEEDBACK ON
SET LINESIZE 80
SET PAGESIZE 14
