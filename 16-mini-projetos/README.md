# 16 — Mini-projetos

Projetos pequenos e completos, cada um em sua própria pasta, juntando modelagem, regra de negócio em PL/SQL e testes de aceite.

Cada projeto traz um `README.md` com o enunciado, o modelo de dados, as decisões de projeto (e as alternativas descartadas), a ordem dos scripts e os testes. Um `instalar.sql` na pasta remove a versão anterior, cria tudo, carrega o exemplo e roda os testes. Os projetos não dependem do schema de exemplo nem uns dos outros; cada um usa um prefixo próprio nos objetos.

| # | Projeto | Prefixo | Pontos principais |
|---|---|---|---|
| 01 | [Controle de estoque](01-estoque/README.md) | `est_` | Saldo materializado, trava de linha contra saldo negativo, transferência sem deadlock, savepoint por operação, kardex |

## Planejados

- [ ] 02 — Biblioteca: empréstimos, devoluções, multa por atraso e reserva
- [ ] 03 — Faturamento simplificado: pedido, nota, parcelas e baixa de títulos
- [ ] 04 — Log e auditoria genéricos: package reutilizável de log com transação autônoma
- [ ] 05 — API em PL/SQL: package de cadastro com validação, exceções próprias e testes utPLSQL
