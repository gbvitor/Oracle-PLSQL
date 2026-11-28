-- =============================================================================
-- Caso   : Validação de CPF e CNPJ (inclusive CNPJ alfanumérico) em PL/SQL,
--          formatação, geração de documento válido e validação por trigger
-- Seção  : 15-casos-de-uso
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); CREATE PROCEDURE, CREATE TRIGGER
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

CREATE OR REPLACE PACKAGE tmp_pkg_documento AS
    -- Tira espaços, pontos, barras e hífens; passa para maiúsculas.
    FUNCTION so_caracteres (p_doc IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;

    -- 'S' válido, 'N' inválido, NULL se a entrada for NULL.
    FUNCTION cpf_valido       (p_cpf  IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION cnpj_valido      (p_cnpj IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION documento_valido (p_tipo IN VARCHAR2, p_doc IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;

    -- Completa a base com os dígitos verificadores (NULL se a base for inválida).
    FUNCTION cpf_com_dv  (p_base IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION cnpj_com_dv (p_base IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;

    -- 999.999.999-99 ou AA.AAA.AAA/AAAA-99; outros tamanhos voltam como vieram.
    FUNCTION formatar (p_doc IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
END tmp_pkg_documento;
/

CREATE OR REPLACE PACKAGE BODY tmp_pkg_documento AS

    TYPE t_pesos IS TABLE OF PLS_INTEGER;

    -- Um dígito pelo módulo 11. Cada posição vale ASCII - 48:
    -- '0'..'9' -> 0..9 e 'A'..'Z' -> 17..42 (regra do CNPJ alfanumérico).
    FUNCTION dv_mod11 (p_base IN VARCHAR2, p_pesos IN t_pesos) RETURN PLS_INTEGER IS
        v_soma  PLS_INTEGER := 0;
        v_resto PLS_INTEGER;
    BEGIN
        FOR i IN 1 .. p_pesos.COUNT LOOP
            v_soma := v_soma + (ASCII(SUBSTR(p_base, i, 1)) - 48) * p_pesos(i);
        END LOOP;
        v_resto := MOD(v_soma, 11);
        RETURN CASE WHEN v_resto < 2 THEN 0 ELSE 11 - v_resto END;
    END dv_mod11;

    FUNCTION todos_iguais (p_doc IN VARCHAR2) RETURN BOOLEAN IS
    BEGIN
        RETURN p_doc = RPAD(SUBSTR(p_doc, 1, 1), LENGTH(p_doc), SUBSTR(p_doc, 1, 1));
    END todos_iguais;

    FUNCTION so_caracteres (p_doc IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    BEGIN
        RETURN UPPER(REGEXP_REPLACE(p_doc, '[[:space:]./-]', ''));
    END so_caracteres;

    FUNCTION cpf_com_dv (p_base IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
        v_base VARCHAR2(11);
    BEGIN
        IF p_base IS NULL OR NOT REGEXP_LIKE(p_base, '^[0-9]{9}$') THEN
            RETURN NULL;
        END IF;
        v_base := p_base || dv_mod11(p_base, t_pesos(10, 9, 8, 7, 6, 5, 4, 3, 2));
        RETURN v_base || dv_mod11(v_base, t_pesos(11, 10, 9, 8, 7, 6, 5, 4, 3, 2));
    END cpf_com_dv;

    FUNCTION cnpj_com_dv (p_base IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
        v_base VARCHAR2(14);
    BEGIN
        IF p_base IS NULL OR NOT REGEXP_LIKE(p_base, '^[0-9A-Z]{12}$') THEN
            RETURN NULL;
        END IF;
        v_base := p_base || dv_mod11(p_base, t_pesos(5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2));
        RETURN v_base || dv_mod11(v_base, t_pesos(6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2));
    END cnpj_com_dv;

    FUNCTION cpf_valido (p_cpf IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
        v_doc VARCHAR2(4000);
    BEGIN
        IF p_cpf IS NULL THEN
            RETURN NULL;
        END IF;
        v_doc := so_caracteres(p_cpf);
        IF NOT REGEXP_LIKE(v_doc, '^[0-9]{11}$') OR todos_iguais(v_doc) THEN
            RETURN 'N';
        END IF;
        RETURN CASE WHEN cpf_com_dv(SUBSTR(v_doc, 1, 9)) = v_doc THEN 'S' ELSE 'N' END;
    END cpf_valido;

    FUNCTION cnpj_valido (p_cnpj IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
        v_doc VARCHAR2(4000);
    BEGIN
        IF p_cnpj IS NULL THEN
            RETURN NULL;
        END IF;
        v_doc := so_caracteres(p_cnpj);
        IF NOT REGEXP_LIKE(v_doc, '^[0-9A-Z]{12}[0-9]{2}$') OR todos_iguais(v_doc) THEN
            RETURN 'N';
        END IF;
        RETURN CASE WHEN cnpj_com_dv(SUBSTR(v_doc, 1, 12)) = v_doc THEN 'S' ELSE 'N' END;
    END cnpj_valido;

    FUNCTION documento_valido (p_tipo IN VARCHAR2, p_doc IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    BEGIN
        RETURN CASE p_tipo
                   WHEN 'F' THEN cpf_valido(p_doc)
                   WHEN 'J' THEN cnpj_valido(p_doc)
               END;
    END documento_valido;

    FUNCTION formatar (p_doc IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
        v_doc VARCHAR2(4000) := so_caracteres(p_doc);
    BEGIN
        RETURN CASE LENGTH(v_doc)
                   WHEN 11 THEN SUBSTR(v_doc, 1, 3) || '.' || SUBSTR(v_doc, 4, 3) || '.'
                             || SUBSTR(v_doc, 7, 3) || '-' || SUBSTR(v_doc, 10, 2)
                   WHEN 14 THEN SUBSTR(v_doc, 1, 2) || '.' || SUBSTR(v_doc, 3, 3) || '.'
                             || SUBSTR(v_doc, 6, 3) || '/' || SUBSTR(v_doc, 9, 4) || '-'
                             || SUBSTR(v_doc, 13, 2)
                   ELSE p_doc
               END;
    END formatar;

END tmp_pkg_documento;
/

SHOW ERRORS PACKAGE BODY tmp_pkg_documento

-- 1. CPF.
SELECT doc, tmp_pkg_documento.cpf_valido(doc) AS valido
  FROM (SELECT '529.982.247-25' AS doc FROM dual UNION ALL
        SELECT '12345678909'           FROM dual UNION ALL
        SELECT '111.111.111-11'        FROM dual UNION ALL
        SELECT '12345678900'           FROM dual UNION ALL
        SELECT '1234567890'            FROM dual UNION ALL
        SELECT NULL                    FROM dual);
-- Esperado: S | S | N (todos iguais) | N (dígito errado) | N (10 dígitos) | NULL

-- 2. CNPJ numérico e alfanumérico.
SELECT doc, tmp_pkg_documento.cnpj_valido(doc) AS valido
  FROM (SELECT '11.222.333/0001-81' AS doc FROM dual UNION ALL
        SELECT '11222333000180'          FROM dual UNION ALL
        SELECT '00.000.000/0000-00'      FROM dual UNION ALL
        SELECT '12.ABC.345/01DE-35'      FROM dual UNION ALL
        SELECT '12ABC34501DE34'          FROM dual UNION ALL
        SELECT '12.abc.345/01de-35'      FROM dual);
-- Esperado: S | N | N (todos iguais) | S (alfanumérico) | N | S (minúsculas são normalizadas)

-- 3. Os clientes do schema: documentos fictícios, todos inválidos.
SELECT id_cliente, tipo_pessoa,
       tmp_pkg_documento.formatar(documento)                      AS documento,
       tmp_pkg_documento.documento_valido(tipo_pessoa, documento) AS valido
  FROM clientes
 ORDER BY id_cliente;
-- Esperado: 12 linhas, todas com N
--           (ex.: 1 J 10.000.000/0001-01 N | 4 F 200.000.000-01 N)

-- 4. Gerar documento válido para teste.
SELECT tmp_pkg_documento.formatar(tmp_pkg_documento.cpf_com_dv('529982247'))     AS cpf,
       tmp_pkg_documento.formatar(tmp_pkg_documento.cnpj_com_dv('112223330001'))  AS cnpj,
       tmp_pkg_documento.formatar(tmp_pkg_documento.cnpj_com_dv('12ABC34501DE'))  AS cnpj_alfa
  FROM dual;
-- Esperado: 529.982.247-25 | 11.222.333/0001-81 | 12.ABC.345/01DE-35

-- 5. Validar na gravação: trigger numa cópia de CLIENTES.
CREATE TABLE tmp_clientes AS SELECT * FROM clientes;

CREATE OR REPLACE TRIGGER tmp_trg_clientes_doc
BEFORE INSERT OR UPDATE OF tipo_pessoa, documento ON tmp_clientes
FOR EACH ROW
BEGIN
    IF NVL(tmp_pkg_documento.documento_valido(:NEW.tipo_pessoa, :NEW.documento), 'N') = 'N' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Documento inválido: ' || :NEW.documento);
    END IF;
    :NEW.documento := tmp_pkg_documento.so_caracteres(:NEW.documento);
END;
/

-- A cópia não tem os DEFAULTs (CTAS não copia), por isso data_cadastro e ativo vão explícitos.
INSERT INTO tmp_clientes (id_cliente, nome, tipo_pessoa, documento, cidade, uf, data_cadastro, ativo)
VALUES (60, 'Cliente de teste PF', 'F', '529.982.247-25', 'Palmas', 'TO', SYSDATE, 'S');
-- Esperado: 1 linha criada

-- Esperado: 60 52998224725 (gravado sem máscara)
SELECT id_cliente, documento FROM tmp_clientes WHERE id_cliente = 60;

-- Esperado: ORA-20001: Documento inválido: 12345678900
INSERT INTO tmp_clientes (id_cliente, nome, tipo_pessoa, documento, cidade, uf, data_cadastro, ativo)
VALUES (61, 'Cliente de teste inválido', 'F', '12345678900', 'Palmas', 'TO', SYSDATE, 'S');

-- O trigger só age no que for gravado: as linhas copiadas continuam inválidas.
-- Alterar outra coluna não dispara (UPDATE OF tipo_pessoa, documento).
UPDATE tmp_clientes SET limite_credito = limite_credito WHERE id_cliente = 1;
-- Esperado: 1 linha atualizada

-- Alterar o documento dispara.
-- Esperado: ORA-20001: Documento inválido: 10000000000199
UPDATE tmp_clientes SET documento = '10000000000199' WHERE id_cliente = 1;

ROLLBACK;

-- 6. Coluna virtual para filtrar e indexar (exige function DETERMINISTIC).
ALTER TABLE tmp_clientes ADD (
    doc_valido AS (CAST(tmp_pkg_documento.documento_valido(tipo_pessoa, documento) AS VARCHAR2(1)))
);

-- Esperado: N 12
SELECT doc_valido, COUNT(*) FROM tmp_clientes GROUP BY doc_valido;

DROP TABLE tmp_clientes PURGE;
DROP PACKAGE tmp_pkg_documento;
