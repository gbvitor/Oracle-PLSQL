-- =============================================================================
-- Tópico : JSON — gerar e ler
-- Seção  : 04-funcoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente); usuário com CREATE TABLE
-- =============================================================================

-- 1. JSON_OBJECT: um objeto por linha.
-- Esperado: {"id":1,"nome":"Papelaria Central Ltda","uf":"SP","limite":50000}
SELECT JSON_OBJECT('id'     VALUE id_cliente,
                   'nome'   VALUE nome,
                   'uf'     VALUE uf,
                   'limite' VALUE limite_credito) AS cliente_json
  FROM clientes
 WHERE id_cliente = 1;

-- 2. NULL ON NULL (padrão) versus ABSENT ON NULL.
--    Cliente 7 não tem e-mail nem limite.
-- Esperado: {"id":7,"email":null,"limite":null} | {"id":7}
SELECT JSON_OBJECT('id' VALUE id_cliente, 'email' VALUE email, 'limite' VALUE limite_credito)
           AS com_nulos,
       JSON_OBJECT('id' VALUE id_cliente, 'email' VALUE email, 'limite' VALUE limite_credito
                   ABSENT ON NULL)
           AS sem_nulos
  FROM clientes
 WHERE id_cliente = 7;

-- 3. Documento completo de um pedido: cabeçalho, cliente e itens.
--    JSON_ARRAYAGG agrega os itens. O JSON_OBJECT do cliente, por vir direto
--    de outra função JSON, entra como objeto. O array vem de uma subquery, e o
--    resultado de subquery é tratado como texto comum: sem FORMAT JSON, ele
--    entraria como string escapada ("[{\"item\":1,...}]").
-- Esperado: {"pedido":1001,"data":"2025-01-08T09:15:00","cliente":{"id":1,"nome":
--           "Papelaria Central Ltda"},"itens":[{"item":1,"produto":8,"qtd":20,
--           "preco":29.9,"desconto":0}, ... 3 itens]}
SELECT JSON_OBJECT(
           'pedido'  VALUE p.id_pedido,
           'data'    VALUE p.data_pedido,
           'cliente' VALUE JSON_OBJECT('id' VALUE c.id_cliente, 'nome' VALUE c.nome),
           'itens'   VALUE (SELECT JSON_ARRAYAGG(
                                       JSON_OBJECT('item'     VALUE i.nr_item,
                                                   'produto'  VALUE i.id_produto,
                                                   'qtd'      VALUE i.quantidade,
                                                   'preco'    VALUE i.preco_unitario,
                                                   'desconto' VALUE i.pct_desconto)
                                       ORDER BY i.nr_item)
                              FROM itens_pedido i
                             WHERE i.id_pedido = p.id_pedido) FORMAT JSON
           RETURNING CLOB) AS pedido_json
  FROM pedidos  p
  JOIN clientes c ON c.id_cliente = p.id_cliente
 WHERE p.id_pedido = 1001;

-- 4. JSON_OBJECTAGG: um objeto com chave = UF e valor = quantidade de clientes.
-- Esperado: {"BA":1,"CE":1,"DF":1,"GO":1,"MG":1,"PE":1,"PR":1,"RS":1,"SP":3,"TO":1}
--           (a ordem das chaves não é garantida)
SELECT JSON_OBJECTAGG(uf VALUE qtd) AS clientes_por_uf
  FROM (SELECT uf, COUNT(*) AS qtd FROM clientes GROUP BY uf);

-- 5. Ler JSON: tabela com coluna CLOB validada por IS JSON.
CREATE TABLE tmp_pedidos_json (
    id   NUMBER PRIMARY KEY,
    doc  CLOB CONSTRAINT ck_tmp_pedidos_json CHECK (doc IS JSON)
);

INSERT INTO tmp_pedidos_json VALUES (1,
'{"pedido": 5001,
  "cliente": {"nome": "Loja Exemplo", "uf": "TO"},
  "itens": [
     {"produto": 8,  "qtd": 10, "preco": 32.5},
     {"produto": 10, "qtd": 2,  "preco": 27.8}
  ]}');

INSERT INTO tmp_pedidos_json VALUES (2,
'{"pedido": 5002,
  "cliente": {"nome": "Outra Loja", "uf": "PA"},
  "itens": [ {"produto": 1, "qtd": 3, "preco": 39.9} ],
  "desconto": 5}');

-- JSON inválido é recusado pela constraint.
-- Esperado: ORA-02290 (CK_TMP_PEDIDOS_JSON violada)
INSERT INTO tmp_pedidos_json VALUES (3, '{"pedido": 5003, "cliente": }');

-- 6. JSON_VALUE, JSON_QUERY, JSON_EXISTS.
-- Esperado:
--   1 | 5001 | Loja Exemplo | TO | [{"produto":8,...},{"produto":10,...}] | 0 | nao
--   2 | 5002 | Outra Loja   | PA | [{"produto":1,...}]                      | 5 | sim
SELECT id,
       JSON_VALUE(doc, '$.pedido' RETURNING NUMBER)                  AS pedido,
       JSON_VALUE(doc, '$.cliente.nome')                             AS cliente,
       JSON_VALUE(doc, '$.cliente.uf')                               AS uf,
       JSON_QUERY(doc, '$.itens')                                    AS itens,
       JSON_VALUE(doc, '$.desconto' RETURNING NUMBER DEFAULT 0 ON EMPTY) AS desconto,
       CASE WHEN JSON_EXISTS(doc, '$.desconto') THEN 'sim' ELSE 'nao' END AS tem_desconto
  FROM tmp_pedidos_json
 ORDER BY id;

-- JSON_VALUE sobre um array devolve nulo em silêncio; com ERROR ON ERROR, erro.
-- Esperado: nulo
SELECT JSON_VALUE(doc, '$.itens') AS silencioso FROM tmp_pedidos_json WHERE id = 1;

-- Esperado: ORA-40456 (JSON_VALUE avaliado para valor não escalar)
SELECT JSON_VALUE(doc, '$.itens' ERROR ON ERROR) AS com_erro FROM tmp_pedidos_json WHERE id = 1;

-- 7. Notação de ponto (precisa do IS JSON e do alias da tabela).
SELECT t.doc.pedido, t.doc.cliente.nome
  FROM tmp_pedidos_json t
 ORDER BY t.id;

-- 8. JSON_TABLE: os itens viram linhas.
-- Esperado: 3 linhas
--   5001 | Loja Exemplo | 8  | 10 | 32.5 | 325
--   5001 | Loja Exemplo | 10 |  2 | 27.8 | 55.6
--   5002 | Outra Loja   | 1  |  3 | 39.9 | 119.7
SELECT jt.pedido, jt.cliente, jt.produto, jt.qtd, jt.preco, jt.qtd * jt.preco AS total
  FROM tmp_pedidos_json t,
       JSON_TABLE(t.doc, '$'
           COLUMNS (
               pedido  NUMBER        PATH '$.pedido',
               cliente VARCHAR2(100) PATH '$.cliente.nome',
               NESTED PATH '$.itens[*]'
                   COLUMNS (
                       produto NUMBER PATH '$.produto',
                       qtd     NUMBER PATH '$.qtd',
                       preco   NUMBER PATH '$.preco'
                   )
           )) jt
 ORDER BY jt.pedido, jt.produto;

-- 9. JSON_SERIALIZE PRETTY [19c+]: formatar para leitura.
SELECT JSON_SERIALIZE(doc RETURNING CLOB PRETTY) AS formatado
  FROM tmp_pedidos_json
 WHERE id = 2;

-- Limpeza
DROP TABLE tmp_pedidos_json PURGE;
