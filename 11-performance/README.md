# 11 — Performance

Ler o que o otimizador decidiu e entender por que uma consulta está lenta antes de mexer nela.

## Tópicos

- [ ] 01 — Como o Oracle executa uma consulta: parse, otimização, execução; hard e soft parse
- [ ] 02 — EXPLAIN PLAN e DBMS_XPLAN.DISPLAY
- [ ] 03 — Plano real: DBMS_XPLAN.DISPLAY_CURSOR e GATHER_PLAN_STATISTICS
- [ ] 04 — Lendo um plano: operações de acesso, joins (nested loops, hash, merge), cardinalidade
- [ ] 05 — Estatísticas: DBMS_STATS, histogramas, estatísticas desatualizadas
- [ ] 06 — Quando um índice é usado e quando é ignorado (função na coluna, conversão implícita, seletividade)
- [ ] 07 — Bind variables e bind peeking
- [ ] 08 — Hints: quando faz sentido e os mais comuns
- [ ] 09 — SQL lento em PL/SQL: linha a linha versus em lote
- [ ] 10 — Ferramentas: AUTOTRACE, SQL Monitor, AWR e ASH (visão geral e licenciamento)
