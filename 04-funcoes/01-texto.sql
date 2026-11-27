-- =============================================================================
-- Tópico : Funções de texto
-- Seção  : 04-funcoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Maiúsculas, minúsculas, iniciais.
-- Esperado: ANA RIBEIRO | ana ribeiro | Papelaria Central Ltda
SELECT UPPER('Ana Ribeiro')              AS maiusculas,
       LOWER('Ana Ribeiro')              AS minusculas,
       INITCAP('PAPELARIA CENTRAL LTDA') AS iniciais
  FROM dual;

-- 2. Trechos: SUBSTR e INSTR.
--    Separar usuário e domínio do e-mail.
-- Esperado (ana.ribeiro@empresa.example): ana.ribeiro | empresa.example
SELECT email,
       SUBSTR(email, 1, INSTR(email, '@') - 1) AS usuario,
       SUBSTR(email, INSTR(email, '@') + 1)    AS dominio
  FROM funcionarios
 WHERE id_funcionario = 100;

-- Primeiro e último nome.
-- Esperado: Ana | Ribeiro
SELECT SUBSTR(nome, 1, INSTR(nome, ' ') - 1) AS primeiro_nome,
       SUBSTR(nome, INSTR(nome, ' ', -1) + 1) AS ultimo_nome
  FROM funcionarios
 WHERE id_funcionario = 100;

-- 3. INSTR devolve 0 quando não encontra; SUBSTR(s, 0) devolve o texto todo.
-- Esperado: 0 | Estagiario
SELECT INSTR('Estagiario', ' ')                            AS posicao,
       SUBSTR('Estagiario', 1, INSTR('Estagiario', ' ') - 1) AS errado_vazio,
       SUBSTR('Estagiario', INSTR('Estagiario', ' '))      AS texto_todo
  FROM dual;
-- errado_vazio sai nulo: SUBSTR com tamanho -1

-- 4. Formatar documento: CPF 99999999999 -> 999.999.999-99.
-- Esperado (cliente 4, documento 20000000001): 200.000.000-01
SELECT documento,
       SUBSTR(documento, 1, 3) || '.' || SUBSTR(documento, 4, 3) || '.' ||
       SUBSTR(documento, 7, 3) || '-' || SUBSTR(documento, 10, 2) AS cpf_formatado
  FROM clientes
 WHERE id_cliente = 4;

-- Limpar formatação: TRANSLATE remove o que não tem correspondente.
-- Esperado: 20000000001
SELECT TRANSLATE('200.000.000-01', '0.-', '0') AS so_digitos FROM dual;

-- 5. LPAD e RPAD completam e cortam.
-- Esperado: 00042 | 42... | 123
SELECT LPAD('42', 5, '0')    AS com_zeros,
       RPAD('42', 5, '.')    AS com_pontos,
       LPAD('12345', 3)      AS cortado
  FROM dual;

-- Código de pedido com 8 dígitos.
-- Esperado: PED-00001001
SELECT 'PED-' || LPAD(id_pedido, 8, '0') AS codigo
  FROM pedidos
 WHERE id_pedido = 1001;

-- 6. TRIM e LTRIM/RTRIM com conjunto.
-- Esperado: [x] | 120 | 12.5 | L
SELECT '[' || TRIM('  x  ') || ']'          AS trim_espacos,
       TRIM(LEADING '0' FROM '00120')        AS sem_zeros_esquerda,
       RTRIM('12.500', '0.')                 AS rtrim_conjunto,
       RTRIM('Ltda.', '.adt')                AS rtrim_surpresa
  FROM dual;

-- 7. REPLACE e TRANSLATE.
-- Esperado: 1234567 | a b c | Ab
SELECT REPLACE('1.234.567', '.')         AS replace_remove,
       REPLACE('a-b-c', '-', ' ')        AS replace_troca,
       TRANSLATE('a-b', 'a-', 'A')       AS translate_remove
  FROM dual;

-- 8. Tirar acentos com TRANSLATE (texto montado com UNISTR para não depender
--    da codificação do cliente: "João Ávila Conceição").
-- Esperado: Joao Avila Conceicao
SELECT TRANSLATE(UNISTR('Jo\00E3o \00C1vila Concei\00E7\00E3o'),
                 UNISTR('\00C1\00C0\00C2\00C3\00C9\00CA\00CD\00D3\00D4\00D5\00DA\00C7\00E1\00E0\00E2\00E3\00E9\00EA\00ED\00F3\00F4\00F5\00FA\00E7'),
                 'AAAAEEIOOOUCaaaaeeiooouc') AS sem_acento
  FROM dual;

-- 9. Tamanho em caracteres e em bytes.
-- Esperado: 4 | 6 (banco AL32UTF8)
SELECT LENGTH(UNISTR('a\00E7\00E3o'))  AS caracteres,
       LENGTHB(UNISTR('a\00E7\00E3o')) AS bytes
  FROM dual;

-- 10. CHR para caracteres de controle: lista com quebra de linha.
SELECT 'Linha 1' || CHR(10) || 'Linha 2' AS duas_linhas FROM dual;

-- 11. Aplicado aos dados: domínios de e-mail dos clientes.
-- Esperado: 6 domínios (email.example com 4) e um grupo nulo com os 3 clientes sem e-mail
SELECT SUBSTR(email, INSTR(email, '@') + 1) AS dominio, COUNT(*) AS clientes
  FROM clientes
 GROUP BY SUBSTR(email, INSTR(email, '@') + 1)
 ORDER BY clientes DESC, dominio;
