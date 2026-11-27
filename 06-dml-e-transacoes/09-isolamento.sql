-- =============================================================================
-- Tópico : Níveis de isolamento — READ COMMITTED, SERIALIZABLE, READ ONLY
-- Seção  : 06-dml-e-transacoes
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente) e DUAS sessões como o usuário
--          de estudo. Execute cada bloco na sessão indicada, na ordem.
-- As alterações confirmadas são desfeitas no fim.
-- =============================================================================

-- ================= PARTE 1: READ COMMITTED (padrão) ==========================

-- SESSÃO A ------------------------------------------------------------------
-- A1. Primeira leitura.
-- Esperado: 39.90
SELECT preco_unitario FROM produtos WHERE id_produto = 1;

-- SESSÃO B ------------------------------------------------------------------
-- B1. Alterar e confirmar.
UPDATE produtos SET preco_unitario = 45.00 WHERE id_produto = 1;
COMMIT;

-- SESSÃO A ------------------------------------------------------------------
-- A2. Mesma consulta, mesma transação: outro resultado.
-- Esperado: 45.00 (leitura não repetível)
SELECT preco_unitario FROM produtos WHERE id_produto = 1;
COMMIT;

-- ======================= PARTE 2: READ ONLY ==================================

-- SESSÃO A ------------------------------------------------------------------
-- A3. Transação somente leitura: fotografia fixa.
SET TRANSACTION READ ONLY;

-- Esperado: 45.00
SELECT preco_unitario FROM produtos WHERE id_produto = 1;

-- SESSÃO B ------------------------------------------------------------------
-- B2. Alterar e confirmar de novo.
UPDATE produtos SET preco_unitario = 50.00 WHERE id_produto = 1;
COMMIT;

-- SESSÃO A ------------------------------------------------------------------
-- A4. A transação READ ONLY continua vendo a fotografia do início.
-- Esperado: 45.00
SELECT preco_unitario FROM produtos WHERE id_produto = 1;

-- A5. DML não é permitido.
-- Esperado: ORA-01456 (não é possível executar operação de inserção/exclusão/atualização numa transação READ ONLY)
UPDATE produtos SET preco_unitario = 1 WHERE id_produto = 1;

-- A6. Encerrar a transação; a próxima leitura vê o valor atual.
COMMIT;

-- Esperado: 50.00
SELECT preco_unitario FROM produtos WHERE id_produto = 1;

-- ===================== PARTE 3: SERIALIZABLE =================================

-- SESSÃO A ------------------------------------------------------------------
-- A7. Transação serializável.
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- Esperado: 50.00
SELECT preco_unitario FROM produtos WHERE id_produto = 1;

-- SESSÃO B ------------------------------------------------------------------
-- B3. Alterar e confirmar a linha que A leu.
UPDATE produtos SET preco_unitario = 55.00 WHERE id_produto = 1;
COMMIT;

-- SESSÃO A ------------------------------------------------------------------
-- A8. A continua vendo 50.00 ...
-- Esperado: 50.00
SELECT preco_unitario FROM produtos WHERE id_produto = 1;

-- A9. ... e não pode alterar uma linha confirmada por outra transação
--     depois do início da sua.
-- Esperado: ORA-08177 (não é possível serializar o acesso para esta transação)
UPDATE produtos SET preco_unitario = preco_unitario + 1 WHERE id_produto = 1;

-- A10. A aplicação desfaz e repete a transação.
ROLLBACK;

-- ======================= PARTE 4: regra do SET TRANSACTION ===================

-- SESSÃO A ------------------------------------------------------------------
-- A11. SET TRANSACTION depois de um DML: erro.
UPDATE produtos SET preco_unitario = preco_unitario WHERE id_produto = 2;

-- Esperado: ORA-01453 (SET TRANSACTION deve ser a primeira instrução da transação)
SET TRANSACTION READ ONLY;

ROLLBACK;

-- ============================ LIMPEZA ========================================

-- SESSÃO A ------------------------------------------------------------------
UPDATE produtos SET preco_unitario = 39.90 WHERE id_produto = 1;
COMMIT;
