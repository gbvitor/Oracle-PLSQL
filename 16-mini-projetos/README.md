# 16 — Mini-projetos

Projetos pequenos e completos, cada um em sua própria pasta, juntando modelagem, regra de negócio em PL/SQL e testes de aceite.

Cada projeto traz um `README.md` com o enunciado, o modelo de dados, as decisões de projeto (e as alternativas descartadas), a ordem dos scripts e os testes. Um `instalar.sql` na pasta remove a versão anterior, cria tudo, carrega o exemplo e roda os testes. Os projetos não dependem do schema de exemplo nem uns dos outros; cada um usa um prefixo próprio nos objetos.

| # | Projeto | Prefixo | Pontos principais |
|---|---|---|---|
| 01 | [Controle de estoque](01-estoque/README.md) | `est_` | Saldo materializado, trava de linha contra saldo negativo, transferência sem deadlock, savepoint por operação, kardex |
| 02 | [Biblioteca](02-biblioteca/README.md) | `bib_` | Índice único parcial, limite por categoria com trava do leitor, multa, renovação, fila de reservas com expiração |
| 03 | [Faturamento simplificado](03-faturamento/README.md) | `fat_` | Numeração sem buraco, parcelas com arredondamento na última, limite de crédito, baixa parcial com encargos, cancelamento |
| 04 | [Log e auditoria genéricos](04-log-e-auditoria/README.md) | `log_` | Log autônomo com níveis, execução e backtrace; trigger de auditoria gerado do dicionário; DDL em transação autônoma |

## Planejados

- [ ] 05 — API em PL/SQL: package de cadastro com validação, exceções próprias e testes utPLSQL
