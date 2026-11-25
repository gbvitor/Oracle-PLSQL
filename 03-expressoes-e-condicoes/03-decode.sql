-- =============================================================================
-- Tópico : DECODE e as diferenças em relação ao CASE
-- Seção  : 03-expressoes-e-condicoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

SET SERVEROUTPUT ON

-- 1. Uso básico, com valor padrão.
SELECT nome,
       DECODE(tipo_pessoa, 'F', 'Pessoa fisica', 'J', 'Pessoa juridica', 'Nao informado') AS tipo
  FROM clientes
 ORDER BY id_cliente;

-- 2. DECODE reconhece NULL.
-- Esperado: 100 "sem comissao" | 104 "com comissao"
SELECT id_funcionario,
       DECODE(pct_comissao, NULL, 'sem comissao', 'com comissao') AS situacao
  FROM funcionarios
 WHERE id_funcionario IN (100, 104);

-- 3. Comparar duas colunas tratando NULL = NULL.
--    Pedidos com vendedor diferente do pedido anterior do mesmo cliente.
--    Com "<>", os pares nulo/nulo e nulo/valor ficariam de fora.
-- Esperado: 6 linhas: 1/1015, 1/1022, 2/1021, 4/1019, 6/1024, 9/1023.
--           Com "<>" sairiam só 3: as de 4, 6 e 9 envolvem vendedor nulo.
SELECT id_cliente, id_pedido, id_vendedor, vendedor_anterior
  FROM (SELECT id_cliente, id_pedido, id_vendedor,
               LAG(id_vendedor) OVER (PARTITION BY id_cliente ORDER BY data_pedido) AS vendedor_anterior,
               ROW_NUMBER()     OVER (PARTITION BY id_cliente ORDER BY data_pedido) AS seq
          FROM pedidos)
 WHERE seq > 1
   AND DECODE(id_vendedor, vendedor_anterior, 0, 1) = 1
 ORDER BY id_cliente, id_pedido;

-- 4. O tipo do resultado vem do primeiro resultado.
--    Primeiro resultado numérico; 'outro' não vira número.
-- Esperado: ORA-01722 (número inválido)
SELECT id_pedido,
       DECODE(status, 'ABERTO', 1, 'FATURADO', 2, 'outro') AS codigo
  FROM pedidos;

--    Primeiro resultado texto: os números viram texto e a ordenação muda.
-- Esperado: ordem 1, 10, 2 (alfabética)
SELECT codigo
  FROM (SELECT DECODE(LEVEL, 1, '1', 2, 2, 3, 10) AS codigo
          FROM dual CONNECT BY LEVEL <= 3)
 ORDER BY codigo;

-- 5. Padrão legado: DECODE + SIGN para comparar maior/menor.
SELECT nome,
       salario,
       DECODE(SIGN(salario - 5000), 1, 'acima de 5 mil', -1, 'abaixo de 5 mil', 'igual') AS faixa
  FROM funcionarios
 ORDER BY salario DESC;

-- 6. DECODE não existe como expressão PL/SQL.
-- Esperado: PLS-00204 (função ou pseudocoluna só pode ser usada em instrução SQL)
DECLARE
    v_texto VARCHAR2(20);
BEGIN
    v_texto := DECODE('F', 'F', 'fisica', 'juridica');
    DBMS_OUTPUT.PUT_LINE(v_texto);
END;
/

-- Com CASE funciona.
DECLARE
    v_texto VARCHAR2(20);
BEGIN
    v_texto := CASE 'F' WHEN 'F' THEN 'fisica' ELSE 'juridica' END;
    DBMS_OUTPUT.PUT_LINE(v_texto);
END;
/
