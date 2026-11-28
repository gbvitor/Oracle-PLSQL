-- =============================================================================
-- Tópico : Variáveis de substituição — DEFINE, uso, VERIFY, NEW_VALUE,
--          ponto final do nome, o caractere solto em textos
-- Seção  : 12-sqlplus-sqlcl
-- Versão : 19c (SQL*Plus ou SQLcl)
-- Requer : schema de exemplo (00-ambiente)
--
-- Todas as variáveis são definidas com DEFINE antes do uso: o script não pergunta nada.
-- Os exemplos que perguntariam estão comentados no fim.
-- =============================================================================

SET DEFINE ON

-- 1. DEFINE e uso, com e sem VERIFY.
DEFINE uf = SP

SET VERIFY ON
SELECT id_cliente, nome FROM clientes WHERE uf = '&uf' ORDER BY id_cliente;
-- Esperado: antes do resultado, duas linhas:
--   old   1: ... o comando como está no script, com a variável
--   new   1: SELECT id_cliente, nome FROM clientes WHERE uf = 'SP' ORDER BY id_cliente
--   e os clientes 1, 2 e 9

SET VERIFY OFF
SELECT id_cliente, nome FROM clientes WHERE uf = '&uf' ORDER BY id_cliente;
-- Esperado: só o resultado

-- 2. Mostrar e remover.
DEFINE uf
-- Esperado: DEFINE UF = "SP" (CHAR)

UNDEFINE uf

-- 3. Substituir nome de objeto e trecho de comando (o que bind não faz).
DEFINE tabela = pedidos
DEFINE filtro = "status = 'ABERTO'"

SELECT COUNT(*) AS qtd FROM &tabela WHERE &filtro;
-- Esperado: 3

-- O ponto encerra o nome da variável quando o texto continua colado.
DEFINE prefixo = itens
SELECT COUNT(*) AS qtd FROM &prefixo._pedido;
-- Esperado: 54 (o texto enviado é "FROM itens_pedido")

UNDEFINE tabela
UNDEFINE filtro
UNDEFINE prefixo

-- 4. NEW_VALUE: o resultado de uma consulta vira variável.
COLUMN maior_cliente NEW_VALUE v_maior_cliente NOPRINT

SELECT id_cliente AS maior_cliente
  FROM (SELECT p.id_cliente,
               SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2)) AS total
          FROM pedidos p
          JOIN itens_pedido i ON i.id_pedido = p.id_pedido
         WHERE p.status <> 'CANCELADO'
         GROUP BY p.id_cliente
         ORDER BY total DESC)
 WHERE ROWNUM = 1;

PROMPT Maior cliente: &v_maior_cliente
-- Esperado: Maior cliente: 10

SELECT nome FROM clientes WHERE id_cliente = &v_maior_cliente;
-- Esperado: Construtora Horizonte Ltda

-- Data no nome de um arquivo (usado no tópico 06).
COLUMN hoje NEW_VALUE v_hoje NOPRINT
SELECT TO_CHAR(SYSDATE, 'YYYYMMDD') AS hoje FROM dual;
PROMPT Arquivo: pedidos_&v_hoje..csv
-- Esperado: Arquivo: pedidos_20261127.csv (a data do dia; os dois pontos: um encerra
--           o nome da variável, o outro fica no texto)

COLUMN maior_cliente CLEAR
COLUMN hoje CLEAR
UNDEFINE v_maior_cliente
UNDEFINE v_hoje

-- 5. O caractere de substituição dentro de um texto.
SET DEFINE OFF
SELECT 'Silva & Filhos' AS fornecedor FROM dual;
SET DEFINE ON
-- Esperado: o texto com o e-comercial, sem pergunta

SELECT 'Silva ' || CHR(38) || ' Filhos' AS fornecedor FROM dual;
-- Esperado: o mesmo texto (CHR(38) é o e-comercial, montado sem aparecer no script)

-- 6. Trocar o caractere de substituição.
SET DEFINE ^
DEFINE uf = TO
SELECT nome FROM clientes WHERE uf = '^uf';
-- Esperado: Colegio Saber Ltda
UNDEFINE uf
SET DEFINE ON

-- 7. Formas que perguntam (rode à mão, fora do script, para ver):
--   SELECT nome FROM clientes WHERE id_cliente = [e-comercial]id;
--       pergunta "Enter value for id:" a cada execução
--   SELECT nome FROM clientes WHERE id_cliente = [e-comercial duplo]id;
--       pergunta uma vez e guarda
--   ACCEPT v_id NUMBER DEFAULT 1 PROMPT 'Cliente (padrão 1): '
--       pergunta com mensagem e valor padrão
--   ACCEPT v_senha CHAR PROMPT 'Senha: ' HIDE
--       não mostra o que é digitado
-- (o caractere aparece por extenso porque comentário com ele também é examinado)

SET VERIFY ON
