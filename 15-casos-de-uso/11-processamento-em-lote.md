# Processamento em lote com controle de commit e log de erros

## Cenário

Milhares de linhas de uma tabela de entrada precisam ser processadas e gravadas no destino. Algumas vão falhar (dado inválido). O processo precisa:

- não parar por causa de uma linha ruim;
- dizer quais linhas falharam e por quê;
- não segurar undo e lock por horas;
- **poder ser retomado** se cair no meio, sem duplicar o que já foi feito;
- deixar um log de execução que sobreviva a um erro.

## Quando fazer commit

| Estratégia | Vantagem | Problema |
|---|---|---|
| Um `COMMIT` no fim | Tudo ou nada; simples | Undo e locks crescem com o volume; uma falha no fim desfaz horas de trabalho |
| `COMMIT` por linha | Nada se perde | Lento: cada commit espera a gravação do redo (seção 11, tópico 09) |
| **`COMMIT` por bloco** (ex.: 1000 linhas) | Volume de undo limitado, desempenho próximo do único commit | Exige marcar o que já foi feito, senão a nova execução repete o que já entrou |

Com commit por bloco, o processo deixa de ser atômico: depois de uma queda, parte está gravada. Por isso a tabela de entrada tem uma **situação** por linha (`N` pendente, `S` processada, `E` erro), atualizada na mesma transação da gravação no destino. A retomada é só rodar de novo: o que já está `S` ou `E` não é lido.

## O desenho

1. Ler o próximo bloco de pendentes: `WHERE situacao = 'N' ORDER BY id FETCH FIRST :limite ROWS ONLY` `[12c+]`, com `BULK COLLECT`.
2. Gravar no destino com `FORALL ... SAVE EXCEPTIONS`: as linhas boas entram e os erros ficam em `SQL%BULK_EXCEPTIONS` (seção 09, tópico 08).
3. Marcar cada linha do bloco como `S` ou `E` (com a mensagem), também com `FORALL`.
4. `COMMIT` e registrar o bloco no log.
5. Repetir até não haver pendente.

Reabrir a consulta a cada bloco, em vez de um cursor aberto atravessando os commits, evita o "fetch across commit", que pode terminar em ORA-01555 (snapshot too old) em processamentos longos, porque o cursor precisa reconstruir pelo undo a visão do momento em que foi aberto.

## O log

O log é gravado por uma procedure com `PRAGMA AUTONOMOUS_TRANSACTION` (seção 09, tópico 12): se o processo falhar e fizer `ROLLBACK`, a linha de log explicando a falha continua lá.

## O que este exemplo não cobre

- **Paralelismo**: duas execuções ao mesmo tempo leriam os mesmos pendentes. Para paralelizar, dividir por faixas de chave; o pacote `DBMS_PARALLEL_EXECUTE` faz essa divisão e controla cada faixa.
- **Erro que não é de linha** (tablespace cheio, deadlock): o bloco é desfeito, o log registra e o erro sobe. Os blocos anteriores já estão gravados e a retomada continua dali.

## Documentação oficial

- [PL/SQL Language Reference — FORALL Statement](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/FORALL-statement.html)
- [Database PL/SQL Packages and Types Reference — DBMS_PARALLEL_EXECUTE](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_PARALLEL_EXECUTE.html)
