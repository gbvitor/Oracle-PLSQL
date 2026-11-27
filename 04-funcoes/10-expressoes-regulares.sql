-- =============================================================================
-- Tópico : REGEXP_SUBSTR, REGEXP_INSTR, REGEXP_REPLACE, REGEXP_COUNT
-- Seção  : 04-funcoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Limpar e formatar documentos.
-- Esperado: 20000000001 | 200.000.000-01 | 10.000.000/0001-01
SELECT REGEXP_REPLACE('200.000.000-01', '[^0-9]')                                         AS so_digitos,
       REGEXP_REPLACE('20000000001', '^(\d{3})(\d{3})(\d{3})(\d{2})$', '\1.\2.\3-\4')     AS cpf,
       REGEXP_REPLACE('10000000000101', '^(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})$',
                      '\1.\2.\3/\4-\5')                                                   AS cnpj
  FROM dual;

-- Aplicado ao cadastro: CPF ou CNPJ conforme o tamanho.
SELECT id_cliente,
       tipo_pessoa,
       CASE LENGTH(documento)
           WHEN 11 THEN REGEXP_REPLACE(documento, '^(\d{3})(\d{3})(\d{3})(\d{2})$', '\1.\2.\3-\4')
           WHEN 14 THEN REGEXP_REPLACE(documento, '^(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})$', '\1.\2.\3/\4-\5')
       END AS documento_formatado
  FROM clientes
 ORDER BY id_cliente;

-- 2. Espaços repetidos.
-- Esperado: [a b c]
SELECT '[' || REGEXP_REPLACE('a   b    c', ' {2,}', ' ') || ']' AS normalizado FROM dual;

-- 3. Extrair número do nome do produto.
--    O primeiro número de "Papel A4 500 folhas" é o 4 de "A4".
-- Esperado: 3 -> 24 | 5 -> 480 | 8 -> 4 (!) | 11 -> 1 | 9 -> 50
SELECT id_produto, nome,
       REGEXP_SUBSTR(nome, '\d+') AS primeiro_numero
  FROM produtos
 WHERE id_produto IN (3, 5, 8, 9, 11)
 ORDER BY id_produto;

-- Só números "soltos" (precedidos de espaço ou início), com vírgula decimal:
-- o Oracle não tem \b, então o limite é simulado e a subexpressão 2 é a devolvida.
-- Esperado: 3 -> 24 | 5 -> 480 | 8 -> 500 | 11 -> 1,20 | 9 -> nulo (cx50 não é solto)
SELECT id_produto, nome,
       REGEXP_SUBSTR(nome, '(^| )(\d+(,\d+)?)', 1, 1, NULL, 2) AS numero_solto
  FROM produtos
 WHERE id_produto IN (3, 5, 8, 9, 11)
 ORDER BY id_produto;

-- 4. REGEXP_INSTR: posição do primeiro dígito e posição depois do número.
-- Esperado: 9 | 11
SELECT REGEXP_INSTR('Monitor 24 polegadas', '\d')          AS inicio,
       REGEXP_INSTR('Monitor 24 polegadas', '\d+', 1, 1, 1) AS depois
  FROM dual;

-- 5. REGEXP_COUNT: palavras e ocorrências.
-- Esperado: Papelaria Central Ltda 3 | Construtora Horizonte Ltda 3 | Clinica Bem Estar Ltda 4
SELECT nome,
       REGEXP_COUNT(nome, '\S+')      AS palavras,
       REGEXP_COUNT(nome, 'a', 1, 'i') AS letras_a
  FROM clientes
 WHERE id_cliente IN (1, 8, 10)
 ORDER BY id_cliente;

-- 6. Quebrar lista em linhas.
-- Esperado: SP, MG, GO
SELECT REGEXP_SUBSTR(lista, '[^,]+', 1, LEVEL) AS item
  FROM (SELECT 'SP,MG,GO' AS lista FROM dual)
CONNECT BY LEVEL <= REGEXP_COUNT(lista, ',') + 1;

-- Com item vazio, '[^,]+' pula e desloca.
-- Esperado: SP | GO | nulo (deveria ser SP | nulo | GO)
SELECT LEVEL AS posicao, REGEXP_SUBSTR(lista, '[^,]+', 1, LEVEL) AS item
  FROM (SELECT 'SP,,GO' AS lista FROM dual)
CONNECT BY LEVEL <= REGEXP_COUNT(lista, ',') + 1;

-- Preservando o vazio com subexpressão.
-- Esperado: SP | nulo | GO
SELECT LEVEL AS posicao, REGEXP_SUBSTR(lista, '([^,]*)(,|$)', 1, LEVEL, NULL, 1) AS item
  FROM (SELECT 'SP,,GO' AS lista FROM dual)
CONNECT BY LEVEL <= REGEXP_COUNT(lista, ',') + 1;

-- 7. Várias linhas de origem: CROSS APPLY por linha.
--    Lista de UFs atendidas por departamento (dados de teste).
-- Esperado: 20 SP | 20 MG | 20 GO | 40 TO | 40 PA
WITH atendimento AS (
    SELECT 20 AS id_departamento, 'SP,MG,GO' AS ufs FROM dual UNION ALL
    SELECT 40,                    'TO,PA'          FROM dual
)
SELECT a.id_departamento, t.uf
  FROM atendimento a
 CROSS APPLY (SELECT REGEXP_SUBSTR(a.ufs, '[^,]+', 1, LEVEL) AS uf
                FROM dual
             CONNECT BY LEVEL <= REGEXP_COUNT(a.ufs, ',') + 1) t
 ORDER BY a.id_departamento;
