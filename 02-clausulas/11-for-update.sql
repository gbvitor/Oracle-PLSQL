-- =============================================================================
-- Tópico : FOR UPDATE, NOWAIT, WAIT, SKIP LOCKED
-- Seção  : 02-clausulas
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente) e DUAS sessões conectadas como o
--          usuário de estudo (duas janelas do SQL*Plus/SQLcl, ou duas abas
--          de editor com sessões separadas).
-- Execute cada bloco na sessão indicada, na ordem. Nada é gravado: tudo
-- termina em ROLLBACK.
-- =============================================================================

-- ============================ SESSÃO A ======================================
-- A1. Bloquear o pedido 1022.
SELECT id_pedido, status
  FROM pedidos
 WHERE id_pedido = 1022
   FOR UPDATE;

-- ============================ SESSÃO B ======================================
-- B1. Ler a mesma linha sem FOR UPDATE: funciona (leitura não é bloqueada).
SELECT id_pedido, status FROM pedidos WHERE id_pedido = 1022;

-- B2. NOWAIT: falha na hora.
-- Esperado: ORA-00054 (recurso ocupado e obtido com NOWAIT especificado)
SELECT id_pedido FROM pedidos WHERE id_pedido = 1022 FOR UPDATE NOWAIT;

-- B3. WAIT 3: espera 3 segundos e falha.
-- Esperado: ORA-30006 (recurso ocupado; adquirir com tempo limite WAIT expirado)
SELECT id_pedido FROM pedidos WHERE id_pedido = 1022 FOR UPDATE WAIT 3;

-- B4. SKIP LOCKED: pega os pedidos em aberto que estiverem livres.
-- Esperado: 1023 e 1024 (o 1022 está com a sessão A)
SELECT id_pedido, status
  FROM pedidos
 WHERE status = 'ABERTO'
   FOR UPDATE SKIP LOCKED;

-- ============================ SESSÃO A ======================================
-- A2. Quem está bloqueando quem (exige acesso a V$SESSION).
--     Enquanto a sessão B estiver esperando num FOR UPDATE sem NOWAIT,
--     blocking_session aponta para a sessão A.
SELECT sid, serial#, username, status, blocking_session, event, seconds_in_wait
  FROM v$session
 WHERE username = USER;

-- A3. Liberar.
ROLLBACK;

-- ============================ SESSÃO B ======================================
-- B5. Liberar os pedidos 1023 e 1024 pegos no B4.
ROLLBACK;

-- ============================ UMA SESSÃO ====================================
-- C1. FOR UPDATE OF: no join, bloquear só os pedidos, não os clientes.
SELECT p.id_pedido, p.status, c.nome
  FROM pedidos  p
  JOIN clientes c ON c.id_cliente = p.id_cliente
 WHERE p.status = 'ABERTO'
   FOR UPDATE OF p.status;

-- Conferir os bloqueios da transação: 1 objeto (PEDIDOS), não 2.
SELECT o.object_name, l.locked_mode
  FROM v$locked_object l
  JOIN user_objects    o ON o.object_id = l.object_id
 WHERE l.session_id = SYS_CONTEXT('USERENV', 'SID');

ROLLBACK;

-- C2. Restrição: FOR UPDATE com GROUP BY.
-- Esperado: ORA-01786 (FOR UPDATE desta expressão de consulta não é permitido)
SELECT status, COUNT(*)
  FROM pedidos
 GROUP BY status
   FOR UPDATE;
