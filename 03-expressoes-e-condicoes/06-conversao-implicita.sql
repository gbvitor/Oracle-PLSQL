-- =============================================================================
-- Tópico : Conversão implícita de tipos
-- Seção  : 03-expressoes-e-condicoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Texto com número: o Oracle converte o texto.
-- Esperado: 15 | 15
SELECT '10' + 5          AS texto_mais_numero,
       10 + TO_NUMBER('5') AS explicito
  FROM dual;

-- 2. Coluna texto comparada com número: conversão aplicada à coluna.
--    O plano mostra TO_NUMBER("DOCUMENTO") no filtro.
EXPLAIN PLAN FOR
SELECT nome FROM clientes WHERE documento = 10000000000101;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +PREDICATE'));

-- 3. Coluna número comparada com texto: o texto é convertido, a coluna não.
--    O índice da chave primária continua utilizável.
EXPLAIN PLAN FOR
SELECT nome FROM clientes WHERE id_cliente = '1';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(format => 'BASIC +PREDICATE'));

-- 4. Data comparada com texto depende do NLS_DATE_FORMAT da sessão.
ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';

-- Esperado: 2 (pedidos 1023 e 1024)
SELECT COUNT(*) AS pedidos_desde_outubro
  FROM pedidos
 WHERE data_pedido >= '01/10/2026';

-- Mesma consulta, outra configuração de sessão.
ALTER SESSION SET NLS_DATE_FORMAT = 'MM/DD/YYYY';

-- Esperado: 8. Sem erro: "01/10/2026" agora é lido como 10 de janeiro de 2026.
SELECT COUNT(*) AS pedidos_desde_outubro
  FROM pedidos
 WHERE data_pedido >= '01/10/2026';

ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD';

-- Esperado: erro de conversão de data (ORA-01830, ORA-01843 ou ORA-01861,
-- conforme a forma como o Oracle tenta encaixar o texto no formato)
SELECT COUNT(*) AS pedidos_desde_outubro
  FROM pedidos
 WHERE data_pedido >= '01/10/2026';

-- Explícito: o mesmo resultado em qualquer sessão.
-- Esperado: 2
SELECT COUNT(*) AS pedidos_desde_outubro
  FROM pedidos
 WHERE data_pedido >= DATE '2026-10-01';

-- 5. TO_DATE sobre uma coluna que já é DATE: ida e volta por texto.
--    Com formato de sessão sem hora, a hora se perde.
ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';

-- Esperado: 30/10/2026 20:30 | 30/10/2026 00:00
SELECT TO_CHAR(data_pedido,          'DD/MM/YYYY HH24:MI') AS original,
       TO_CHAR(TO_DATE(data_pedido), 'DD/MM/YYYY HH24:MI') AS depois_do_to_date
  FROM pedidos
 WHERE id_pedido = 1024;

-- 6. Conversão implícita em INSERT: também depende da sessão.
CREATE TABLE tmp_datas (d DATE, n NUMBER);

-- Esperado: funciona com NLS_DATE_FORMAT = DD/MM/YYYY
INSERT INTO tmp_datas (d) VALUES ('25/11/2026');

ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD';

-- Esperado: erro de conversão de data com a outra configuração
INSERT INTO tmp_datas (d) VALUES ('25/11/2026');

-- Separador decimal: '10,5' só vira número se a sessão usa vírgula.
ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,';

-- Esperado: ORA-01722 (número inválido)
INSERT INTO tmp_datas (n) VALUES ('10,5');

ROLLBACK;
DROP TABLE tmp_datas PURGE;
