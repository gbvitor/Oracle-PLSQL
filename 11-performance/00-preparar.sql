-- =============================================================================
-- Tópico : Preparação da seção 11 — tabelas de teste com volume
-- Seção  : 11-performance
-- Versão : 19c
-- Requer : usuário de estudo (00-ambiente), cerca de 40 MB livres na cota
--
-- O schema de exemplo é pequeno demais para o otimizador variar de plano.
-- Os scripts desta seção usam duas tabelas geradas, com distribuição conhecida:
--
--   TMP_PERF_CLIENTES   2.000 linhas
--     segmento   ATACADO em 100 clientes (id múltiplo de 20), VAREJO nos demais
--     uf         10 UFs, 200 clientes cada
--     codigo_ext VARCHAR2 com conteúdo numérico ('100001' a '102000')
--
--   TMP_PERF_PEDIDOS    200.000 linhas
--     id_cliente  100 pedidos para cada cliente
--     data_pedido 2024-01-01 a 2025-12-31, 273 ou 274 pedidos por dia, com hora
--     status      ENTREGUE 197.800 | ABERTO 2.000 | CANCELADO 200  (distribuição torta,
--                 de propósito, para o tópico de histogramas)
--
-- Rode uma vez antes dos tópicos 02 a 10. Para remover: 99-limpar.sql.
-- =============================================================================

CREATE TABLE tmp_perf_clientes (
    id_cliente NUMBER(6)     CONSTRAINT pk_tmp_perf_clientes PRIMARY KEY,
    nome       VARCHAR2(60)  NOT NULL,
    uf         CHAR(2)       NOT NULL,
    segmento   VARCHAR2(10)  NOT NULL,
    codigo_ext VARCHAR2(10)  NOT NULL
);

INSERT INTO tmp_perf_clientes
SELECT LEVEL,
       'Cliente ' || LEVEL,
       CASE MOD(LEVEL, 10)
           WHEN 0 THEN 'SP' WHEN 1 THEN 'MG' WHEN 2 THEN 'RJ' WHEN 3 THEN 'PR' WHEN 4 THEN 'RS'
           WHEN 5 THEN 'BA' WHEN 6 THEN 'GO' WHEN 7 THEN 'TO' WHEN 8 THEN 'PE' ELSE 'DF'
       END,
       CASE WHEN MOD(LEVEL, 20) = 0 THEN 'ATACADO' ELSE 'VAREJO' END,
       TO_CHAR(100000 + LEVEL)
  FROM dual
CONNECT BY LEVEL <= 2000;

CREATE TABLE tmp_perf_pedidos (
    id_pedido   NUMBER(10)    CONSTRAINT pk_tmp_perf_pedidos PRIMARY KEY,
    id_cliente  NUMBER(6)     NOT NULL
                CONSTRAINT fk_tmp_perf_ped_cliente REFERENCES tmp_perf_clientes (id_cliente),
    data_pedido DATE          NOT NULL,
    status      VARCHAR2(12)  NOT NULL,
    valor       NUMBER(12,2)  NOT NULL,
    observacao  VARCHAR2(100)
);

INSERT /*+ APPEND */ INTO tmp_perf_pedidos
SELECT LEVEL,
       MOD(LEVEL * 7919, 2000) + 1,
       DATE '2024-01-01' + MOD(LEVEL * 13, 731) + MOD(LEVEL, 86400) / 86400,
       CASE
           WHEN MOD(LEVEL, 1000) = 0 THEN 'CANCELADO'
           WHEN MOD(LEVEL, 100) = 1  THEN 'ABERTO'
           ELSE 'ENTREGUE'
       END,
       ROUND(MOD(LEVEL * 37, 10000) / 7 + 10, 2),
       RPAD('pedido ' || LEVEL, 60, '.')
  FROM dual
CONNECT BY LEVEL <= 200000;

COMMIT;

CREATE INDEX tmp_ix_perf_ped_cliente ON tmp_perf_pedidos (id_cliente);
CREATE INDEX tmp_ix_perf_ped_data    ON tmp_perf_pedidos (data_pedido);
CREATE INDEX tmp_ix_perf_ped_status  ON tmp_perf_pedidos (status);
CREATE INDEX tmp_ix_perf_cli_codigo  ON tmp_perf_clientes (codigo_ext);

-- Estatísticas sem histograma: o tópico 05 mostra a diferença que o histograma faz.
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'TMP_PERF_CLIENTES', method_opt => 'FOR ALL COLUMNS SIZE 1', cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'TMP_PERF_PEDIDOS',  method_opt => 'FOR ALL COLUMNS SIZE 1', cascade => TRUE);
END;
/

-- Conferência.
-- Esperado: ABERTO 2000 | CANCELADO 200 | ENTREGUE 197800
SELECT status, COUNT(*) FROM tmp_perf_pedidos GROUP BY status ORDER BY status;

-- Esperado: 100 | 100 (todo cliente com 100 pedidos)
SELECT MIN(qtd), MAX(qtd) FROM (SELECT id_cliente, COUNT(*) AS qtd FROM tmp_perf_pedidos GROUP BY id_cliente);

-- Esperado: TMP_PERF_CLIENTES 2000 | TMP_PERF_PEDIDOS 200000
SELECT table_name, num_rows FROM user_tables WHERE table_name LIKE 'TMP_PERF%' ORDER BY 1;
