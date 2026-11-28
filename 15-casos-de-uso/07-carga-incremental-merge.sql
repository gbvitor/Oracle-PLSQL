-- =============================================================================
-- Caso   : Carga incremental de produtos com MERGE — validação, só o que mudou,
--          inativação dos ausentes, log e idempotência
-- Seção  : 15-casos-de-uso
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
--
-- Trabalha em cópias (TMP_PRODUTOS como destino, TMP_STG_PRODUTOS como staging).
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

CREATE TABLE tmp_produtos AS SELECT id_produto, nome, id_categoria, unidade, preco_unitario, ativo FROM produtos;
ALTER TABLE tmp_produtos ADD CONSTRAINT pk_tmp_produtos PRIMARY KEY (id_produto);

CREATE TABLE tmp_stg_produtos (
    id_produto     NUMBER(6),
    nome           VARCHAR2(100),
    id_categoria   NUMBER(4),
    unidade        VARCHAR2(5),
    preco_unitario NUMBER(10,2)
);

-- A "lista do dia" vinda da origem:
--   todos os produtos atuais, exceto o 14 (descontinuado) e o 15 (já inativo);
--   produto 2 com preço novo; produto 3 com nome novo; produtos 16 e 17 novos.
INSERT INTO tmp_stg_produtos
SELECT id_produto,
       CASE id_produto WHEN 3 THEN 'Monitor 24 pol Full HD' ELSE nome END,
       id_categoria,
       unidade,
       CASE id_produto WHEN 2 THEN 94.90 ELSE preco_unitario END
  FROM produtos
 WHERE id_produto NOT IN (14, 15);

INSERT INTO tmp_stg_produtos VALUES (16, 'Suporte para notebook', 2, 'UN', 129.90);
INSERT INTO tmp_stg_produtos VALUES (17, 'Filtro de linha',       2, 'UN',  59.90);
COMMIT;

-- 1. Validar a staging.
-- Esperado: nenhuma linha (sem chave repetida)
SELECT id_produto, COUNT(*) FROM tmp_stg_produtos GROUP BY id_produto HAVING COUNT(*) > 1;

-- Esperado: nenhuma linha (sem obrigatório vazio, sem preço inválido, categoria existente)
SELECT s.*
  FROM tmp_stg_produtos s
 WHERE s.nome IS NULL
    OR s.preco_unitario IS NULL OR s.preco_unitario <= 0
    OR NOT EXISTS (SELECT 1 FROM categorias c WHERE c.id_categoria = s.id_categoria);

-- 2. A carga.
DECLARE
    v_merge      PLS_INTEGER;
    v_inativados PLS_INTEGER;
    v_antes      PLS_INTEGER;
    v_depois     PLS_INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_antes FROM tmp_produtos;

    MERGE INTO tmp_produtos t
    USING tmp_stg_produtos s
       ON (t.id_produto = s.id_produto)
     WHEN MATCHED THEN UPDATE
          SET t.nome           = s.nome,
              t.id_categoria   = s.id_categoria,
              t.unidade        = s.unidade,
              t.preco_unitario = s.preco_unitario,
              t.ativo          = 'S'
        WHERE DECODE(t.nome, s.nome, 0, 1) = 1
           OR DECODE(t.id_categoria, s.id_categoria, 0, 1) = 1
           OR DECODE(t.unidade, s.unidade, 0, 1) = 1
           OR DECODE(t.preco_unitario, s.preco_unitario, 0, 1) = 1
           OR t.ativo <> 'S'
     WHEN NOT MATCHED THEN INSERT (id_produto, nome, id_categoria, unidade, preco_unitario, ativo)
          VALUES (s.id_produto, s.nome, s.id_categoria, s.unidade, s.preco_unitario, 'S');
    v_merge := SQL%ROWCOUNT;

    SELECT COUNT(*) INTO v_depois FROM tmp_produtos;

    -- Inativar quem não veio na lista.
    UPDATE tmp_produtos t
       SET t.ativo = 'N'
     WHERE t.ativo = 'S'
       AND NOT EXISTS (SELECT 1 FROM tmp_stg_produtos s WHERE s.id_produto = t.id_produto);
    v_inativados := SQL%ROWCOUNT;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Inseridos:   ' || (v_depois - v_antes));
    DBMS_OUTPUT.PUT_LINE('Alterados:   ' || (v_merge - (v_depois - v_antes)));
    DBMS_OUTPUT.PUT_LINE('Inativados:  ' || v_inativados);
END;
/
-- Esperado: Inseridos: 2 | Alterados: 2 | Inativados: 1
--           (alterados: produto 2, preço, e produto 3, nome; inativado: 14)

-- Esperado: 2 94.9 S | 3 Monitor 24 pol Full HD S | 14 N | 15 N | 16 S | 17 S
SELECT id_produto, nome, preco_unitario, ativo
  FROM tmp_produtos
 WHERE id_produto IN (2, 3, 14, 15, 16, 17)
 ORDER BY id_produto;

-- 3. Rodar de novo: nada muda (idempotente).
DECLARE
    v_merge      PLS_INTEGER;
    v_inativados PLS_INTEGER;
BEGIN
    MERGE INTO tmp_produtos t
    USING tmp_stg_produtos s
       ON (t.id_produto = s.id_produto)
     WHEN MATCHED THEN UPDATE
          SET t.nome = s.nome, t.id_categoria = s.id_categoria, t.unidade = s.unidade,
              t.preco_unitario = s.preco_unitario, t.ativo = 'S'
        WHERE DECODE(t.nome, s.nome, 0, 1) = 1
           OR DECODE(t.id_categoria, s.id_categoria, 0, 1) = 1
           OR DECODE(t.unidade, s.unidade, 0, 1) = 1
           OR DECODE(t.preco_unitario, s.preco_unitario, 0, 1) = 1
           OR t.ativo <> 'S'
     WHEN NOT MATCHED THEN INSERT (id_produto, nome, id_categoria, unidade, preco_unitario, ativo)
          VALUES (s.id_produto, s.nome, s.id_categoria, s.unidade, s.preco_unitario, 'S');
    v_merge := SQL%ROWCOUNT;

    UPDATE tmp_produtos t
       SET t.ativo = 'N'
     WHERE t.ativo = 'S'
       AND NOT EXISTS (SELECT 1 FROM tmp_stg_produtos s WHERE s.id_produto = t.id_produto);
    v_inativados := SQL%ROWCOUNT;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Segunda execução: MERGE ' || v_merge || ' | inativados ' || v_inativados);
END;
/
-- Esperado: Segunda execução: MERGE 0 | inativados 0

-- 4. Sem a condição de mudança: tudo o que casa é "atualizado".
MERGE INTO tmp_produtos t
USING tmp_stg_produtos s
   ON (t.id_produto = s.id_produto)
 WHEN MATCHED THEN UPDATE SET t.preco_unitario = s.preco_unitario;
-- Esperado: 15 linhas mescladas (as 13 originais da staging e as 2 novas),
--           sem nenhum valor diferente: trabalho, redo e histórico à toa
ROLLBACK;

-- 5. Chave repetida na staging: o MERGE falha.
INSERT INTO tmp_stg_produtos VALUES (2, 'Teclado ABNT2', 2, 'UN', 99.90);
COMMIT;

-- Esperado: ORA-30926 (não foi possível obter um conjunto estável de linhas)
MERGE INTO tmp_produtos t
USING tmp_stg_produtos s
   ON (t.id_produto = s.id_produto)
 WHEN MATCHED THEN UPDATE SET t.preco_unitario = s.preco_unitario;

-- A validação do passo 1 teria pegado.
-- Esperado: 2 | 2
SELECT id_produto, COUNT(*) FROM tmp_stg_produtos GROUP BY id_produto HAVING COUNT(*) > 1;

-- Uma forma de seguir: ficar com uma linha por chave (aqui, a de maior preço) na origem do MERGE.
MERGE INTO tmp_produtos t
USING (SELECT * FROM (SELECT s.*, ROW_NUMBER() OVER (PARTITION BY id_produto ORDER BY preco_unitario DESC) AS rn
                        FROM tmp_stg_produtos s)
        WHERE rn = 1) s
   ON (t.id_produto = s.id_produto)
 WHEN MATCHED THEN UPDATE SET t.preco_unitario = s.preco_unitario
                      WHERE DECODE(t.preco_unitario, s.preco_unitario, 0, 1) = 1;
-- Esperado: 1 linha mesclada (produto 2 para 99,90)
ROLLBACK;

DROP TABLE tmp_stg_produtos PURGE;
DROP TABLE tmp_produtos PURGE;
