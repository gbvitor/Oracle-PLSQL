-- =============================================================================
-- Caso   : Texto delimitado — quebrar em linhas (REGEXP_SUBSTR, LATERAL,
--          JSON_TABLE) e juntar linhas em texto (LISTAGG, DISTINCT, OVERFLOW, XMLAGG)
-- Seção  : 15-casos-de-uso
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

-- 1. Um texto: REGEXP_SUBSTR + CONNECT BY.
-- Esperado: 1 SP | 2 MG | 3 GO | 4 TO
SELECT LEVEL AS pos,
       REGEXP_SUBSTR('SP,MG,GO,TO', '[^,]+', 1, LEVEL) AS uf
  FROM dual
CONNECT BY LEVEL <= REGEXP_COUNT('SP,MG,GO,TO', ',') + 1;

-- Lista de parâmetro num IN, com bind e sem SQL dinâmico.
VARIABLE lista VARCHAR2(100)
EXEC :lista := 'SP,TO'

-- Esperado: 1 SP | 2 SP | 6 TO | 9 SP
SELECT id_cliente, uf
  FROM clientes
 WHERE uf IN (SELECT REGEXP_SUBSTR(:lista, '[^,]+', 1, LEVEL)
                FROM dual
             CONNECT BY LEVEL <= REGEXP_COUNT(:lista, ',') + 1)
 ORDER BY id_cliente;

-- 2. Uma coluna com lista: preferências de categoria por cliente.
CREATE TABLE tmp_preferencias (
    id_cliente NUMBER(6)     CONSTRAINT pk_tmp_preferencias PRIMARY KEY,
    categorias VARCHAR2(100)
);

INSERT INTO tmp_preferencias VALUES (1, '2;5;6');
INSERT INTO tmp_preferencias VALUES (3, '5');
INSERT INTO tmp_preferencias VALUES (4, '2;3;;7');
INSERT INTO tmp_preferencias VALUES (6, NULL);
COMMIT;

-- 2a. CROSS JOIN LATERAL [12c+], preservando a posição do elemento vazio.
SELECT p.id_cliente, x.pos, x.id_categoria
  FROM tmp_preferencias p
 CROSS JOIN LATERAL (
       SELECT LEVEL AS pos,
              REGEXP_SUBSTR(p.categorias, '([^;]*)(;|$)', 1, LEVEL, NULL, 1) AS id_categoria
         FROM dual
      CONNECT BY LEVEL <= REGEXP_COUNT(p.categorias, ';') + 1) x
 WHERE p.categorias IS NOT NULL
 ORDER BY p.id_cliente, x.pos;
-- Esperado: 8 linhas
--   1 1 2 | 1 2 5 | 1 3 6 | 3 1 5 | 4 1 2 | 4 2 3 | 4 3 (nulo) | 4 4 7
-- Sem o filtro de NULL, o cliente 6 apareceria com uma linha: o CONNECT BY
-- devolve sempre o primeiro nível, mesmo com a condição desconhecida.

-- A armadilha do '[^;]+': o elemento vazio some e as posições andam.
-- Esperado: 1 2 | 2 3 | 3 7 | 4 (nulo)
SELECT LEVEL AS pos, REGEXP_SUBSTR('2;3;;7', '[^;]+', 1, LEVEL) AS id_categoria
  FROM dual
CONNECT BY LEVEL <= REGEXP_COUNT('2;3;;7', ';') + 1;

-- 2b. JSON_TABLE [12c+]: '2;5;6' vira '["2","5","6"]'.
SELECT p.id_cliente, j.pos, j.id_categoria
  FROM tmp_preferencias p,
       JSON_TABLE('["' || REPLACE(p.categorias, ';', '","') || '"]', '$[*]'
                  COLUMNS (pos          FOR ORDINALITY,
                           id_categoria VARCHAR2(10) PATH '$')) j
 WHERE p.categorias IS NOT NULL
 ORDER BY p.id_cliente, j.pos;
-- Esperado: as mesmas 8 linhas de 2a (o vazio vira NULL, porque texto vazio é NULL no Oracle)

-- 3. Quebrar, juntar com o cadastro e juntar de novo em texto.
SELECT p.id_cliente,
       LISTAGG(c.nome, ', ') WITHIN GROUP (ORDER BY x.pos) AS categorias
  FROM tmp_preferencias p
 CROSS JOIN LATERAL (
       SELECT LEVEL AS pos,
              REGEXP_SUBSTR(p.categorias, '([^;]*)(;|$)', 1, LEVEL, NULL, 1) AS id_categoria
         FROM dual
      CONNECT BY LEVEL <= REGEXP_COUNT(p.categorias, ';') + 1) x
  JOIN categorias c ON c.id_categoria = TO_NUMBER(x.id_categoria)
 WHERE p.categorias IS NOT NULL
 GROUP BY p.id_cliente
 ORDER BY p.id_cliente;
-- Esperado:
--   1 Perifericos, Papelaria, Moveis
--   3 Papelaria
--   4 Perifericos, Armazenamento, Cadeiras   (o vazio não casa com categoria)

-- 4. LISTAGG: produtos por categoria.
SELECT id_categoria,
       COUNT(*) AS qtd,
       LISTAGG(nome, ', ') WITHIN GROUP (ORDER BY nome) AS produtos
  FROM produtos
 GROUP BY id_categoria
 ORDER BY id_categoria;
-- Esperado:
--   2 5 Hub USB 4 portas, Monitor 24 polegadas, Mouse optico USB, Teclado ABNT2, Webcam Full HD
--   3 3 HD externo 1 TB, Pen drive 64 GB, SSD 480 GB
--   5 3 Caneta esferografica azul cx50, Grampeador 26/6, Papel A4 500 folhas
--   6 2 Armario 2 portas, Mesa de escritorio 1,20 m
--   7 2 Cadeira fixa, Cadeira giratoria

-- LISTAGG como função analítica: a lista ao lado de cada linha.
-- Esperado: 13 Cadeira giratoria | Cadeira fixa, Cadeira giratoria
--           14 Cadeira fixa      | Cadeira fixa, Cadeira giratoria
SELECT id_produto, nome,
       LISTAGG(nome, ', ') WITHIN GROUP (ORDER BY nome) OVER (PARTITION BY id_categoria) AS mesma_categoria
  FROM produtos
 WHERE id_categoria = 7
 ORDER BY id_produto;

-- 5. LISTAGG DISTINCT [19c].
SELECT uf,
       LISTAGG(cidade, ', ')          WITHIN GROUP (ORDER BY cidade) AS com_repeticao,
       LISTAGG(DISTINCT cidade, ', ') WITHIN GROUP (ORDER BY cidade) AS sem_repeticao
  FROM clientes
 WHERE uf IN ('SP', 'MG')
 GROUP BY uf
 ORDER BY uf;
-- Esperado:
--   MG Belo Horizonte                | Belo Horizonte
--   SP Campinas, Sao Paulo, Sao Paulo | Campinas, Sao Paulo

-- 6. Passar de 4000 bytes: 1000 códigos de 4 dígitos com vírgula = 4999 caracteres.
-- Esperado: ORA-01489 (o resultado da concatenação de strings é longo demais)
SELECT LISTAGG(TO_CHAR(LEVEL, 'FM0000'), ',') WITHIN GROUP (ORDER BY LEVEL) AS lista
  FROM dual
CONNECT BY LEVEL <= 1000;

-- ON OVERFLOW TRUNCATE [12.2+]: corta no último valor inteiro e diz quantos faltaram.
-- Esperado: texto com até 4000 caracteres terminando em ',...(N)', N perto de 200
SELECT LENGTH(lista) AS tamanho, SUBSTR(lista, -20) AS final
  FROM (SELECT LISTAGG(TO_CHAR(LEVEL, 'FM0000'), ',' ON OVERFLOW TRUNCATE '...' WITH COUNT)
                 WITHIN GROUP (ORDER BY LEVEL) AS lista
          FROM dual
        CONNECT BY LEVEL <= 1000);

-- Resultado inteiro em CLOB: XMLAGG.
-- Esperado: 4999 | 0001,0002,0003 | 0998,0999,1000
SELECT DBMS_LOB.GETLENGTH(lista)    AS tamanho,
       DBMS_LOB.SUBSTR(lista, 14, 1) AS inicio,
       DBMS_LOB.SUBSTR(lista, 14, DBMS_LOB.GETLENGTH(lista) - 13) AS final
  FROM (SELECT RTRIM(XMLAGG(XMLELEMENT(e, TO_CHAR(LEVEL, 'FM0000') || ',') ORDER BY LEVEL)
                       .EXTRACT('//text()').GETCLOBVAL(), ',') AS lista
          FROM dual
        CONNECT BY LEVEL <= 1000);

DROP TABLE tmp_preferencias PURGE;
