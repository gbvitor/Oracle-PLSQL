# 03 — Faturamento simplificado

## Enunciado

Do pedido ao recebimento:

- **faturar** um pedido: gerar a nota com número sequencial sem buraco por série, copiar os itens e gerar os títulos conforme a condição de pagamento (à vista, 30/60, 30/60/90...);
- recusar o faturamento se o cliente estiver inativo ou se o valor em aberto mais a nota passar do limite de crédito;
- **baixar** títulos, com pagamento parcial e encargos de atraso (multa de 2% e juros de 0,03% ao dia sobre o valor pago);
- **cancelar** nota sem pagamento: títulos cancelados, pedido volta a aberto, o número não é reaproveitado.

Não há cálculo de impostos: o foco é a mecânica de numeração, parcelas, limite e baixa.

## Modelo

```
fat_clientes ──< fat_pedidos ──< fat_itens_pedido >── fat_produtos
                     │   └── fat_condicoes ──< fat_condicoes_parcelas
                     │
fat_numeracao ──< fat_notas ──< fat_itens_nota
                     └──< fat_titulos ──< fat_baixas
```

| Tabela | Conteúdo |
|---|---|
| `fat_numeracao` | Último número usado por série |
| `fat_condicoes`, `fat_condicoes_parcelas` | Condição de pagamento: prazo em dias e percentual de cada parcela |
| `fat_pedidos`, `fat_itens_pedido` | O pedido: `ABERTO`, `FATURADO` ou `CANCELADO` |
| `fat_notas`, `fat_itens_nota` | A nota (`EMITIDA` ou `CANCELADA`) e a cópia dos itens no momento do faturamento |
| `fat_titulos` | Uma linha por parcela: vencimento, valor, valor pago, `ABERTO` / `PAGO` / `CANCELADO` |
| `fat_baixas` | Cada pagamento, com os encargos calculados |

## Decisões de projeto

| Decisão | Alternativa descartada | Por quê |
|---|---|---|
| **Tabela de numeração** atualizada com `UPDATE ... RETURNING` | Sequence | Sequence pode pular números (cache perdido no restart, `NEXTVAL` de uma transação que fez rollback). Numeração fiscal não pode ter buraco. O `UPDATE` trava a linha da série até o fim da transação: faturamentos da mesma série ficam em fila, e um rollback devolve o número. O custo é essa serialização, aceitável para nota fiscal |
| **Itens copiados** para `fat_itens_nota` | A nota apontar para os itens do pedido | Documento emitido não muda. Se o pedido for alterado ou o preço do produto mudar, a nota continua como foi emitida |
| **Última parcela recebe a diferença** do arredondamento | Arredondar todas pelo percentual | 1.323,93 em três parcelas de 33,33% dá 441,27 + 441,27 + 441,27 = 1.323,81: faltam 12 centavos. A última fica com 441,39 e a soma bate com a nota (teste T02) |
| Item arredondado **antes** de somar | Arredondar o total | O valor de cada item é o que aparece impresso; somar os valores sem arredondar pode dar um centavo de diferença em relação à soma impressa |
| Trava do **pedido** e do **cliente** no faturamento | Só conferir | O pedido não é faturado duas vezes ao mesmo tempo; duas notas do mesmo cliente não passam juntas pelo limite, cada uma vendo o em aberto sem a outra |
| **Índice único parcial** para nota emitida por pedido | `UNIQUE (id_pedido)` | O pedido pode ter notas canceladas no histórico e uma emitida (mesma técnica do mini-projeto 02) |
| Encargos calculados **na baixa** e gravados | Calcular só na consulta | O que foi cobrado fica registrado, mesmo que a regra de juros mude depois |
| Cancelamento só **sem baixa** | Cancelar e estornar automaticamente | Dinheiro recebido exige decisão (devolver, compensar); o processo de estorno é separado |

## Erros da package

| Código | Exceção | Quando |
|---|---|---|
| −20301 | `e_pedido_nao_aberto` | Pedido inexistente, já faturado ou cancelado |
| −20302 | `e_pedido_sem_itens` | Pedido sem itens ou com total zero |
| −20303 | `e_cliente_inativo` | Cliente inativo |
| −20304 | `e_limite_credito` | Em aberto + nota maior que o limite |
| −20305 | `e_nota_com_baixa` | Cancelar nota que já tem pagamento |
| −20306 | `e_titulo_nao_aberto` | Baixar título inexistente, pago ou cancelado |
| −20307 | `e_valor_invalido` | Valor de baixa nulo, zero, negativo ou com mais de 2 casas |
| −20308 | `e_valor_acima_do_saldo` | Pagamento maior que o saldo do título |
| −20309 | `e_nota_nao_emitida` | Cancelar nota inexistente ou já cancelada |
| −20310 | `e_motivo_obrigatorio` | Cancelar sem motivo |
| −20311 | `e_serie_inexistente` | Série não cadastrada em `fat_numeracao` |
| −20312 | `e_condicao_invalida` | Condição sem parcelas ou com percentuais que não somam 100 |

## Scripts

| Ordem | Script | Conteúdo |
|---|---|---|
| — | [instalar.sql](instalar.sql) | Roda todos na ordem, depois de remover a versão anterior |
| 1 | [01-tabelas.sql](01-tabelas.sql) | Tabelas, constraints, índices |
| 2 | [02-pacote.sql](02-pacote.sql) | `fat_pkg_faturamento` |
| 3 | [03-views.sql](03-views.sql) | `fat_vw_posicao_cliente`, `fat_vw_titulos_abertos` (data do servidor) |
| 4 | [04-carga.sql](04-carga.sql) | Três clientes, quatro produtos, três condições, seis pedidos; três notas e duas baixas |
| 5 | [05-testes-de-aceite.sql](05-testes-de-aceite.sql) | 26 testes em sequência, data de referência 28/11/2026; termina com `ROLLBACK` |
| — | [99-remover.sql](99-remover.sql) | Remove tudo; pode rodar mais de uma vez |

Requer `CREATE TABLE`, `CREATE VIEW` e `CREATE PROCEDURE`. Não usa o schema de exemplo.

## Estado depois da carga

| Nota | Pedido | Cliente | Total | Títulos |
|---|---|---|---|---|
| 1 | 1 | A | 1.323,93 | 441,27 (04/11, pago) · 441,27 (04/12) · 441,39 (03/01/2027) |
| 2 | 2 | B | 940,50 | 940,50 (20/10): pagos 500,00 em 30/10 com 11,50 de encargos; saldo 440,50 |
| 3 | 3 | A | 1.798,00 | 899,00 (10/12) · 899,00 (09/01/2027) |

| Cliente | Limite | Em aberto |
|---|---|---|
| A | 10.000,00 | 2.680,66 |
| B | 3.000,00 | 440,50 |
| C (inativo) | 5.000,00 | 0 |

O pedido 4 (cliente B, 2.697,00) fica aberto: com os 440,50 em aberto, passa do limite.

## Testes de aceite

Os 26 testes conferem as parcelas e o arredondamento, os encargos, o limite de crédito (recusa, quitação do atraso e faturamento liberado), as recusas de pedido faturado, sem itens, de cliente inativo e de série inexistente (com a garantia de que a recusa não consome número nem deixa resto), as validações e a baixa parcial, o cancelamento e o refaturamento com o número seguinte, a numeração sem buraco, o índice único parcial e a soma das baixas.

A saída termina com `26 de 26 testes passaram`.

### Teste manual da numeração (duas sessões)

Preparação, numa sessão, com a carga recém-instalada (último número: 3):

```sql
INSERT INTO fat_pedidos (id_pedido, id_cliente, id_condicao, data_pedido) VALUES (101, 1, 1, SYSDATE);
INSERT INTO fat_itens_pedido VALUES (101, 1, 1, 1, 120, 0);
INSERT INTO fat_pedidos (id_pedido, id_cliente, id_condicao, data_pedido) VALUES (102, 1, 1, SYSDATE);
INSERT INTO fat_itens_pedido VALUES (102, 1, 1, 2, 120, 0);
COMMIT;
```

| Passo | Sessão A | Sessão B |
|---|---|---|
| 1 | `VARIABLE n NUMBER` e `EXEC :n := fat_pkg_faturamento.faturar(101)` — sem commit; a nota fica com o número 4 | |
| 2 | | `VARIABLE n NUMBER` e `EXEC :n := fat_pkg_faturamento.faturar(102)` — **fica esperando** (A trava o cliente A e a série) |
| 3 | `ROLLBACK` | |
| 4 | | O faturamento termina; `SELECT numero FROM fat_notas WHERE id_nota = :n` dá **4**: o número que A tinha usado voltou |
| 5 | | `ROLLBACK` |

Com uma sequence, B teria recebido 5 e o 4 ficaria perdido.

## Para ir além

- Estorno de baixa, que permitiria cancelar nota paga.
- Impostos por item (alíquota por produto e por estado de destino), com o total da nota passando a incluir o imposto.
- Juros compostos ou por taxa mensal pro rata, com a taxa numa tabela de parâmetros por vigência.
- Conciliação: arquivo de retorno do banco carregado com o caso 07 da seção 15 e baixado em lote com o caso 11.
