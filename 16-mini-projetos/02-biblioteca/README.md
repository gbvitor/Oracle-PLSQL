# 02 — Biblioteca

## Enunciado

Controlar o acervo e a circulação de uma biblioteca:

- empréstimo com prazo e limite por categoria de leitor (aluno, professor);
- devolução com multa por dia de atraso; multa pendente ou empréstimo atrasado impedem novo empréstimo;
- renovação, com limite e recusada se houver alguém esperando a obra;
- reserva com fila: quando o exemplar volta, fica separado para o primeiro da fila por 2 dias; se não for retirado, a reserva expira e o exemplar passa ao próximo.

## Modelo

```
bib_categorias_leitor ──< bib_leitores ──< bib_emprestimos >── bib_exemplares >── bib_obras
                                     └───< bib_reservas >──────────────────────────────┘
```

| Tabela | Conteúdo |
|---|---|
| `bib_categorias_leitor` | Regras: máximo de empréstimos, dias de prazo, multa por dia, máximo de renovações |
| `bib_leitores` | Leitor, categoria, ativo |
| `bib_obras` | O título |
| `bib_exemplares` | O volume físico, com a situação: `DISPONIVEL`, `EMPRESTADO`, `RESERVADO`, `BAIXADO` |
| `bib_emprestimos` | Empréstimo e devolução, multa e se foi paga |
| `bib_reservas` | Fila por obra: `ATIVA` → `DISPONIVEL` (exemplar separado) → `ATENDIDA`, ou `CANCELADA` / `EXPIRADA` |

## Decisões de projeto

| Decisão | Por quê |
|---|---|
| **Índice único parcial** `CASE WHEN data_devolucao IS NULL THEN id_exemplar END` | Garante no banco que um exemplar tem no máximo um empréstimo aberto, sem impedir o histórico (as linhas devolvidas dão NULL, que não entra no índice). O Oracle não tem índice com `WHERE` como o PostgreSQL; o `CASE` faz o papel. O mesmo recurso garante uma reserva aberta por leitor e obra |
| Reserva é da **obra**, empréstimo é do **exemplar** | O leitor quer o título, não um volume específico; quem voltar primeiro atende a fila |
| Trava do **leitor** (`FOR UPDATE`) no começo do empréstimo | Contar os empréstimos abertos e depois gravar deixa uma janela: duas sessões emprestando ao mesmo leitor leem "2 de 3" e as duas passam. Com a trava, a segunda espera e conta 3 |
| Trava do **exemplar** antes de mudar a situação | Dois balcões não emprestam o mesmo volume; o índice único seria a segunda barreira |
| Fila lida com cursor `FOR UPDATE` e atualizada com `WHERE CURRENT OF` | O primeiro da fila fica travado até a transação terminar; cancelamento simultâneo da mesma reserva espera |
| Ordem fixa das regras no empréstimo: leitor, multa, atraso, limite, exemplar | O leitor recebe sempre o mesmo motivo para a mesma situação, e os testes conseguem esperar um código só |
| Datas como **parâmetro** com padrão `TRUNC(SYSDATE)` | Os testes rodam com datas fixas, em qualquer dia. Só a view de atrasos usa a data do servidor |
| Expiração como **função separada** | É um processo de lote, não reação a um evento: em produção, um job diário (`DBMS_SCHEDULER`, seção 13, tópico 08) chama `expirar_reservas` |

## Erros da package

| Código | Exceção | Quando |
|---|---|---|
| −20201 | `e_leitor_invalido` | Leitor inexistente ou inativo |
| −20202 | `e_limite_emprestimos` | Já tem o máximo da categoria |
| −20203 | `e_multa_pendente` | Multa não paga |
| −20204 | `e_emprestimo_em_atraso` | Algum empréstimo aberto passou do prazo |
| −20205 | `e_exemplar_indisponivel` | Inexistente, emprestado, baixado ou separado para outro leitor |
| −20206 | `e_renovacao_em_atraso` | Renovar depois do prazo |
| −20207 | `e_limite_renovacoes` | Já renovou o máximo da categoria |
| −20208 | `e_obra_com_fila` | Renovar com reserva na fila |
| −20209 | `e_obra_disponivel` | Reservar obra que tem exemplar disponível |
| −20210 | `e_reserva_duplicada` | Leitor já tem reserva aberta da obra |
| −20211 | `e_nao_emprestado` | Devolver exemplar ou renovar empréstimo que não está aberto |
| −20212 | `e_obra_inexistente` | Reservar obra que não existe |
| −20213 | `e_reserva_fechada` | Cancelar reserva inexistente ou já encerrada |

## Scripts

| Ordem | Script | Conteúdo |
|---|---|---|
| — | [instalar.sql](instalar.sql) | Roda todos na ordem, depois de remover a versão anterior |
| 1 | [01-tabelas.sql](01-tabelas.sql) | Tabelas, constraints, índices únicos parciais |
| 2 | [02-pacote.sql](02-pacote.sql) | `bib_pkg_biblioteca` |
| 3 | [03-views.sql](03-views.sql) | `bib_vw_atrasos` (data do servidor), `bib_vw_fila_reservas` |
| 4 | [04-carga.sql](04-carga.sql) | Duas categorias, cinco leitores, cinco obras, oito exemplares, movimento de novembro de 2026 |
| 5 | [05-testes-de-aceite.sql](05-testes-de-aceite.sql) | 23 testes em sequência, data de referência 28/11/2026; termina com `ROLLBACK` |
| — | [99-remover.sql](99-remover.sql) | Remove tudo; pode rodar mais de uma vez |

Requer `CREATE TABLE`, `CREATE VIEW` e `CREATE PROCEDURE`. Não usa o schema de exemplo.

## Estado depois da carga

| Regra | Aluno | Professor |
|---|---|---|
| Empréstimos simultâneos | 3 | 5 |
| Prazo | 7 dias | 14 dias |
| Multa por dia | 1,50 | 1,00 |
| Renovações | 1 | 2 |

| Exemplar | Situação | Com quem | Previsto |
|---|---|---|---|
| 102 (obra 1) | Emprestado, 1 renovação | Professor 01 | 30/11 |
| 201 (obra 2) | Emprestado | Aluno 01 (retirou a reserva) | 20/11 (em atraso em 28/11) |
| 401 (obra 4) | Baixado | — | — |
| 101, 301, 501, 502, 503 | Disponíveis | — | — |

O Aluno 02 tem multa de 4,50 (devolveu o 201 com 3 dias de atraso). O Professor 01 está na fila da obra 2.

## Testes de aceite

Os 23 testes contam uma história a partir da carga: o Aluno 02 paga a multa e chega ao limite de três livros; o Aluno 01, atrasado, não consegue emprestar nem renovar; o Professor 01 renova até o limite, entra na fila de outra obra e impede uma renovação; o 201 volta com 8 dias de atraso (12,00 de multa), fica separado para o Professor 01, não é retirado, a reserva expira e o exemplar fica disponível. No meio, as recusas de exemplar baixado, leitor inativo, reserva duplicada e reserva de obra disponível, e o índice único barrando um empréstimo duplicado gravado direto na tabela. O último teste confere que a situação de cada exemplar bate com empréstimos e reservas.

A saída termina com `23 de 23 testes passaram`; um teste que falha mostra o erro que veio no lugar do esperado.

## Para ir além

- Dias úteis no prazo e na multa, com a tabela de feriados do caso 08 da seção 15.
- Suspensão em vez de multa: `bloqueado_ate` no leitor, calculado na devolução.
- Avisar o leitor quando a reserva fica disponível: gravar numa fila de notificações que outro processo envia.
- Histórico de situação do exemplar com o pacote de auditoria do mini-projeto 04.
