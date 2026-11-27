-- =============================================================================
-- Tópico : Records — %ROWTYPE, TYPE RECORD, aninhados, atribuição e DML
-- Seção  : 08-plsql-fundamentos
-- Versão : 19c (passo 6 exige 18c+)
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

-- 1. %ROWTYPE de tabela.
DECLARE
    r clientes%ROWTYPE;
BEGIN
    SELECT * INTO r FROM clientes WHERE id_cliente = 3;
    DBMS_OUTPUT.PUT_LINE(r.nome || ' | ' || r.cidade || '/' || r.uf || ' | limite ' || r.limite_credito);
    DBMS_OUTPUT.PUT_LINE('E-mail nulo? ' || CASE WHEN r.email IS NULL THEN 'sim' ELSE 'não' END);
END;
/
-- Esperado: Escritorio Modelo SA | Belo Horizonte/MG | limite 80000 | E-mail nulo? sim

-- 2. RECORD próprio, com valores iniciais e campo NOT NULL.
DECLARE
    TYPE t_resumo_cliente IS RECORD (
        id_cliente  clientes.id_cliente%TYPE,
        nome        clientes.nome%TYPE,
        qtd_pedidos PLS_INTEGER := 0,
        total       NUMBER NOT NULL := 0
    );

    r t_resumo_cliente;
BEGIN
    DBMS_OUTPUT.PUT_LINE('Antes: qtd ' || r.qtd_pedidos || ' | total ' || r.total || ' | nome [' || r.nome || ']');

    SELECT c.id_cliente,
           c.nome,
           COUNT(DISTINCT p.id_pedido),
           SUM(ROUND(i.quantidade * i.preco_unitario * (1 - i.pct_desconto / 100), 2))
      INTO r
      FROM clientes c
      JOIN pedidos p      ON p.id_cliente = c.id_cliente
      JOIN itens_pedido i ON i.id_pedido = p.id_pedido
     WHERE c.id_cliente = 3
       AND p.status <> 'CANCELADO'
     GROUP BY c.id_cliente, c.nome;

    DBMS_OUTPUT.PUT_LINE('Depois: ' || r.nome || ' | ' || r.qtd_pedidos || ' pedidos | total ' || r.total);
END;
/
-- Esperado:
--   Antes: qtd 0 | total 0 | nome []
--   Depois: Escritorio Modelo SA | 3 pedidos | total 28994.22

-- 3. Record aninhado.
DECLARE
    TYPE t_endereco IS RECORD (
        cidade clientes.cidade%TYPE,
        uf     clientes.uf%TYPE
    );

    TYPE t_contato IS RECORD (
        nome     clientes.nome%TYPE,
        endereco t_endereco
    );

    r t_contato;
BEGIN
    SELECT nome, cidade, uf
      INTO r.nome, r.endereco.cidade, r.endereco.uf
      FROM clientes
     WHERE id_cliente = 6;

    DBMS_OUTPUT.PUT_LINE(r.nome || ' - ' || r.endereco.cidade || '/' || r.endereco.uf);
END;
/
-- Esperado: Colegio Saber Ltda - Palmas/TO

-- 4. Atribuição entre records: mesmo tipo pode; tipos diferentes não.
DECLARE
    TYPE t_a IS RECORD (id NUMBER, nome VARCHAR2(100));
    r1 t_a;
    r2 t_a;
BEGIN
    r1.id   := 1;
    r1.nome := 'Papelaria Central Ltda';
    r2      := r1;
    DBMS_OUTPUT.PUT_LINE('Cópia: ' || r2.id || ' ' || r2.nome);
END;
/
-- Esperado: Cópia: 1 Papelaria Central Ltda

DECLARE
    TYPE t_a IS RECORD (id NUMBER, nome VARCHAR2(100));
    TYPE t_b IS RECORD (id NUMBER, nome VARCHAR2(100));
    r1 t_a;
    r2 t_b;
BEGIN
    r2 := r1;
END;
/
-- Esperado: erro de compilação PLS-00382 (expressão do tipo incorreto),
--           embora os dois tipos tenham os mesmos campos

-- 5. Records não se comparam com "=".
DECLARE
    TYPE t_a IS RECORD (id NUMBER, nome VARCHAR2(100));
    r1 t_a;
    r2 t_a;
BEGIN
    IF r1 = r2 THEN
        NULL;
    END IF;
END;
/
-- Esperado: erro de compilação PLS-00306 (número ou tipos de argumentos errados na chamada para '=')

-- 6. [18c+] Expressão qualificada: preencher o record numa linha.
DECLARE
    TYPE t_item IS RECORD (
        id_produto NUMBER,
        quantidade NUMBER,
        preco      NUMBER
    );

    r t_item;
BEGIN
    r := t_item(id_produto => 8, quantidade => 10, preco => 32.50);
    DBMS_OUTPUT.PUT_LINE('Produto ' || r.id_produto || ': ' || r.quantidade * r.preco);
END;
/
-- Esperado: Produto 8: 325

-- 7. "Zerar" um record: atribuir um do mesmo tipo nunca preenchido.
DECLARE
    TYPE t_acumulador IS RECORD (
        qtd   PLS_INTEGER := 0,
        total NUMBER := 0
    );

    r       t_acumulador;
    r_vazio t_acumulador;
BEGIN
    r.qtd   := 5;
    r.total := 1234.5;
    r := r_vazio;
    DBMS_OUTPUT.PUT_LINE('Depois de zerar: qtd ' || r.qtd || ' | total ' || r.total);
END;
/
-- Esperado: Depois de zerar: qtd 0 | total 0 (voltam os valores iniciais do tipo)

-- 8. Records em INSERT, UPDATE SET ROW e RETURNING INTO.
CREATE TABLE tmp_clientes AS SELECT * FROM clientes;

DECLARE
    r clientes%ROWTYPE;

    TYPE t_retorno IS RECORD (
        id_cliente     clientes.id_cliente%TYPE,
        nome           clientes.nome%TYPE,
        limite_credito clientes.limite_credito%TYPE
    );
    r_ret t_retorno;

    v_qtd PLS_INTEGER;
BEGIN
    -- Copiar o cliente 3 como um cliente novo.
    SELECT * INTO r FROM tmp_clientes WHERE id_cliente = 3;
    r.id_cliente    := 50;
    r.nome          := 'Escritorio Modelo Filial';
    r.documento     := '10000000000150';
    r.data_cadastro := DATE '2026-01-15';

    INSERT INTO tmp_clientes VALUES r;

    SELECT COUNT(*) INTO v_qtd FROM tmp_clientes;
    DBMS_OUTPUT.PUT_LINE('Clientes depois do INSERT: ' || v_qtd);

    -- Regravar a linha inteira a partir do record.
    r.cidade := 'Contagem';
    UPDATE tmp_clientes SET ROW = r WHERE id_cliente = r.id_cliente;
    DBMS_OUTPUT.PUT_LINE('SET ROW: ' || SQL%ROWCOUNT || ' linha');

    -- Ler o que foi gravado sem SELECT extra.
    UPDATE tmp_clientes
       SET limite_credito = limite_credito * 1.1
     WHERE id_cliente = 3
    RETURNING id_cliente, nome, limite_credito INTO r_ret;

    DBMS_OUTPUT.PUT_LINE('RETURNING: ' || r_ret.id_cliente || ' ' || r_ret.nome || ' -> ' || r_ret.limite_credito);
END;
/
-- Esperado:
--   Clientes depois do INSERT: 13
--   SET ROW: 1 linha
--   RETURNING: 3 Escritorio Modelo SA -> 88000

-- Esperado: 50 | Escritorio Modelo Filial | Contagem | MG | 80000
SELECT id_cliente, nome, cidade, uf, limite_credito FROM tmp_clientes WHERE id_cliente = 50;

ROLLBACK;
DROP TABLE tmp_clientes PURGE;
