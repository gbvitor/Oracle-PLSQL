# 01 — Controle de estoque

## Enunciado

Controlar a quantidade de cada produto em cada depósito, com:

- entradas, saídas, transferências entre depósitos e ajustes de inventário;
- **saldo nunca negativo**, inclusive com duas pessoas movimentando o mesmo produto ao mesmo tempo;
- histórico completo (kardex) que explique o saldo atual;
- lista de produtos abaixo do estoque mínimo.

## Modelo

```
est_depositos (1) ──< est_saldos >── (1) est_produtos
       │                                   │
       └──────────< est_movimentos >───────┘
```

| Tabela | Conteúdo |
|---|---|
| `est_produtos` | Cadastro, estoque mínimo, ativo |
| `est_depositos` | Locais de estoque |
| `est_movimentos` | Histórico imutável: tipo, sinal (+1/−1), quantidade sempre positiva, data, documento. A transferência gera duas linhas ligadas por `id_transferencia` |
| `est_saldos` | Saldo atual por produto e depósito, com `CHECK (quantidade >= 0)` |

## Decisões de projeto

| Decisão | Alternativa descartada | Por quê |
|---|---|---|
| **Saldo materializado** em `est_saldos`, atualizado junto com o movimento | Calcular `SUM` dos movimentos a cada consulta | Consulta de saldo é muito mais frequente que movimento, e a soma cresce com o histórico. O custo é manter as duas coisas iguais; o teste T18 confere |
| Toda gravação pela **package**; sem trigger | Trigger em `est_movimentos` atualizando o saldo | Regra explícita num lugar só, sem efeito escondido e sem tabela mutante (seção 09, tópico 05). Em produção, o usuário da aplicação recebe só `EXECUTE` na package, não `INSERT` nas tabelas |
| **`SELECT ... FOR UPDATE`** na linha de saldo antes de conferir | Conferir o saldo e depois gravar, sem travar | Sem a trava, duas saídas simultâneas leem o mesmo saldo, as duas passam e o resultado fica negativo (ou o CHECK derruba uma delas com erro genérico). Com a trava, a segunda espera a primeira terminar e confere o saldo já atualizado |
| Linha de saldo criada com `INSERT` + `DUP_VAL_ON_INDEX` | `SELECT` para saber se existe e depois `INSERT` | Entre o `SELECT` e o `INSERT` outra sessão pode criar a linha. O `INSERT` direto deixa a chave primária resolver |
| Transferência trava os dois saldos **sempre na mesma ordem** | Travar origem e depois destino | Duas transferências cruzadas (1→2 e 2→1) travariam uma a origem da outra: deadlock (ORA-00060) |
| **`SAVEPOINT`** em cada operação | Confiar no rollback automático | O Oracle desfaz sozinho só a instrução que falhou. Numa transferência que falha na segunda linha, a primeira ficaria gravada se quem chamou tratar a exceção e seguir. O `ROLLBACK TO` desfaz a operação inteira |
| **Sem `COMMIT`** na package | Commit no fim de cada operação | Quem chama pode juntar várias operações numa transação (uma nota com dez itens entra inteira ou não entra) |
| Exceções nomeadas na especificação, com `PRAGMA EXCEPTION_INIT` | Só `RAISE_APPLICATION_ERROR` | Quem chama trata por nome (`WHEN est_pkg_estoque.e_saldo_insuficiente`) em vez de comparar `SQLCODE` |

## Erros da package

| Código | Exceção | Quando |
|---|---|---|
| −20101 | `e_saldo_insuficiente` | Saída ou transferência maior que o saldo |
| −20102 | `e_quantidade_invalida` | Nula, negativa, zero (exceto contagem de ajuste) ou com mais de 3 casas |
| −20103 | `e_produto_invalido` | Produto inexistente ou inativo |
| −20104 | `e_deposito_invalido` | Depósito inexistente |
| −20105 | `e_mesmo_deposito` | Transferência com origem igual ao destino |
| −20106 | `e_motivo_obrigatorio` | Ajuste sem motivo |

## Scripts

| Ordem | Script | Conteúdo |
|---|---|---|
| — | [instalar.sql](instalar.sql) | Roda todos na ordem, depois de remover a versão anterior |
| 1 | [01-tabelas.sql](01-tabelas.sql) | Tabelas, constraints, índices, sequence |
| 2 | [02-pacote.sql](02-pacote.sql) | `est_pkg_estoque` |
| 3 | [03-views.sql](03-views.sql) | `est_vw_kardex`, `est_vw_abaixo_minimo` |
| 4 | [04-carga.sql](04-carga.sql) | Dois depósitos, seis produtos, movimentos de novembro de 2026 |
| 5 | [05-testes-de-aceite.sql](05-testes-de-aceite.sql) | 21 testes; termina com `ROLLBACK` |
| — | [99-remover.sql](99-remover.sql) | Remove tudo; pode rodar mais de uma vez |

Requer `CREATE TABLE`, `CREATE SEQUENCE`, `CREATE VIEW` e `CREATE PROCEDURE`. Não usa o schema de exemplo.

## Saldos depois da carga

| Produto | Depósito 1 | Depósito 2 | Total | Mínimo |
|---|---|---|---|---|
| 1 Parafuso | 45 | 12 | 57 | 10 |
| 2 Porca | 8 | — | 8 | 10 (abaixo) |
| 3 Arruela | 47 | — | 47 | 5 |
| 4 Fita isolante | 19 | — | 19 | 20 (abaixo) |
| 5 Cabo (m) | 349,5 | 113,25 | 462,75 | 100 |
| 6 Lâmpada (inativo) | — | — | 0 | 0 |

## Testes de aceite

`05-testes-de-aceite.sql` imprime uma linha por teste e o total, por exemplo `21 de 21 testes passaram`. Cobrem os saldos da carga, todas as recusas da tabela de erros, a atomicidade da transferência, o ajuste sem diferença, a consistência entre saldo e movimentos, o kardex e o CHECK como última barreira.

### Teste manual de concorrência (duas sessões)

Não dá para testar trava numa sessão só. Com a carga recém-instalada (produto 1, depósito 1, saldo 45):

| Passo | Sessão A | Sessão B |
|---|---|---|
| 1 | `VARIABLE id NUMBER` e `EXEC :id := est_pkg_estoque.saida(1, 1, 40, 'A')` — sem commit | |
| 2 | | `VARIABLE id NUMBER` e `EXEC :id := est_pkg_estoque.saida(1, 1, 10, 'B')` — **fica esperando** |
| 3 | `COMMIT` | |
| 4 | | Recebe **ORA-20101**: saldo 5, solicitado 10 |
| 5 | | `ROLLBACK` |

Sem o `FOR UPDATE`, B leria o saldo 45 antes do commit de A, passaria na conferência e só o CHECK impediria o −5, com um ORA-02290 que não diz nada ao usuário. Depois do teste, reinstale para voltar ao saldo da carga.

## Para ir além

- Custo médio ponderado: guardar o valor unitário na entrada e recalcular o custo do saldo.
- Lote e validade: a chave do saldo passa a ser produto, depósito e lote; saída escolhe o lote que vence primeiro.
- Reserva: uma coluna de quantidade reservada, com o disponível = saldo − reservado.
- Testes com utPLSQL (seção 09, tópico 17) no lugar do bloco de testes.
