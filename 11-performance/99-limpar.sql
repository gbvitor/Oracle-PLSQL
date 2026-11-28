-- =============================================================================
-- Tópico : Limpeza da seção 11 — remove as tabelas de teste
-- Seção  : 11-performance
-- Versão : 19c
-- Requer : 00-preparar.sql
-- =============================================================================

DROP TABLE tmp_perf_pedidos  PURGE;
DROP TABLE tmp_perf_clientes PURGE;
