-- =============================================================================
-- Tópico : GREATEST, LEAST, SYS_GUID, ORA_HASH, STANDARD_HASH, SYS_CONTEXT,
--          DUMP, DBMS_RANDOM
-- Seção  : 04-funcoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. GREATEST e LEAST comparam argumentos da mesma linha.
--    Data mais recente entre o cadastro e o último pedido de cada cliente.
SELECT c.id_cliente,
       c.data_cadastro,
       u.ultimo_pedido,
       GREATEST(c.data_cadastro, u.ultimo_pedido)                         AS com_nulo,
       GREATEST(c.data_cadastro, NVL(u.ultimo_pedido, c.data_cadastro))   AS tratado
  FROM clientes c
  LEFT JOIN (SELECT id_cliente, MAX(data_pedido) AS ultimo_pedido
               FROM pedidos GROUP BY id_cliente) u
    ON u.id_cliente = c.id_cliente
 ORDER BY c.id_cliente;
-- Clientes 11 e 12 (sem pedido): com_nulo sai nulo; tratado mostra o cadastro.

-- 2. O tipo vem do primeiro argumento.
-- Esperado: 9 (texto: '9' > '10') | 10 (número)
SELECT GREATEST('10', 9) AS primeiro_texto,
       GREATEST(10, '9') AS primeiro_numero
  FROM dual;

-- 3. SYS_GUID: identificador único em RAW e em texto.
SELECT SYS_GUID()            AS guid_raw,
       RAWTOHEX(SYS_GUID())  AS guid_texto
  FROM dual;

-- 4. ORA_HASH: distribuir clientes em 3 grupos de forma estável.
--    O mesmo id cai sempre no mesmo grupo; os tamanhos dos grupos dependem
--    da função de hash, não são necessariamente iguais.
SELECT ORA_HASH(id_cliente, 2) AS grupo,
       COUNT(*)                AS clientes,
       LISTAGG(id_cliente, ',') WITHIN GROUP (ORDER BY id_cliente) AS ids
  FROM clientes
 GROUP BY ORA_HASH(id_cliente, 2)
 ORDER BY grupo;

-- 5. STANDARD_HASH: pseudonimizar o e-mail e detectar mudança de conteúdo.
SELECT id_cliente,
       email,
       STANDARD_HASH(email, 'SHA256')                 AS email_sha256,
       STANDARD_HASH(nome || '|' || cidade || '|' || uf, 'MD5') AS assinatura_cadastro
  FROM clientes
 WHERE id_cliente IN (1, 2);

-- Mesmo texto, mesmo hash; um caractere diferente, hash completamente diferente.
-- Esperado: iguais = S | diferentes = N
SELECT CASE WHEN STANDARD_HASH('Ana Ribeiro', 'SHA256') = STANDARD_HASH('Ana Ribeiro', 'SHA256')
            THEN 'S' ELSE 'N' END AS iguais,
       CASE WHEN STANDARD_HASH('Ana Ribeiro', 'SHA256') = STANDARD_HASH('Ana Ribeir0', 'SHA256')
            THEN 'S' ELSE 'N' END AS diferentes
  FROM dual;

-- 6. Contexto da sessão.
SELECT USER                                        AS usuario,
       SYS_CONTEXT('USERENV', 'SESSION_USER')      AS session_user,
       SYS_CONTEXT('USERENV', 'OS_USER')           AS usuario_so,
       SYS_CONTEXT('USERENV', 'HOST')              AS maquina,
       SYS_CONTEXT('USERENV', 'IP_ADDRESS')        AS ip,
       SYS_CONTEXT('USERENV', 'MODULE')            AS programa,
       SYS_CONTEXT('USERENV', 'SID')               AS sid
  FROM dual;

-- 7. DUMP: descobrir caractere invisível que quebra a comparação.
--    O segundo valor tem um espaço não separável (código 160) no fim.
-- Esperado: igual = N | tam_a 2, tam_b 3 | dump_b termina em 194,160 (o espaço não separável em UTF-8)
WITH valores AS (
    SELECT 'SP'                        AS a,
           'SP' || UNISTR('\00A0')     AS b
      FROM dual
)
SELECT CASE WHEN a = b THEN 'S' ELSE 'N' END AS igual,
       LENGTH(a) AS tam_a,
       LENGTH(b) AS tam_b,
       DUMP(a)   AS dump_a,
       DUMP(b)   AS dump_b
  FROM valores;

-- 8. DBMS_RANDOM: massa de teste reproduzível com SEED.
BEGIN
    DBMS_RANDOM.SEED(42);
END;
/

SELECT LEVEL                                     AS n,
       ROUND(DBMS_RANDOM.VALUE(100, 1000), 2)   AS valor,
       DBMS_RANDOM.STRING('U', 3) || '-' || LPAD(TRUNC(DBMS_RANDOM.VALUE(0, 10000)), 4, '0') AS codigo
  FROM dual
CONNECT BY LEVEL <= 5;
-- Rodando de novo o bloco do SEED e esta consulta, os valores se repetem.
