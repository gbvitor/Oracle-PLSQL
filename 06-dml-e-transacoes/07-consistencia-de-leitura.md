# Consistência de leitura e UNDO

## Leitores não bloqueiam escritores, escritores não bloqueiam leitores

No Oracle, uma consulta **nunca espera** por uma alteração em andamento e **nunca vê** dados não confirmados de outra sessão. Isso vale sem configuração e sem hint: é o comportamento padrão.

Funciona assim: ao alterar um bloco, o Oracle guarda a versão anterior dos dados no **undo**. Uma consulta que encontra um bloco alterado depois de ter começado (ou alterado por uma transação ainda não confirmada) monta, a partir do undo, a versão do bloco no momento em que **ela** começou. O resultado é uma "fotografia" consistente.

## O ponto da fotografia

| Nível | Momento da fotografia |
|---|---|
| Comando (padrão, `READ COMMITTED`) | O início de **cada comando**. Dois `SELECT` seguidos podem ver dados diferentes se outra sessão confirmou algo entre eles |
| Transação (`SERIALIZABLE` ou `READ ONLY`) | O início da **transação**. Todos os comandos veem a mesma fotografia (tópico 09) |

Dentro de um único comando, mesmo que ele leve uma hora, todas as linhas são lidas como estavam no início: uma soma de saldos não mistura valores de antes e de depois de uma transferência feita no meio da leitura.

A própria sessão vê as **suas** alterações não confirmadas.

## ORA-01555: snapshot too old

Uma consulta longa precisa que o undo necessário para montar a fotografia continue existindo até o fim. Se o undo foi sobrescrito (porque o espaço acabou e a retenção não segurou), a consulta falha com **ORA-01555**.

Causas comuns:

- Consulta muito longa sobre uma tabela muito alterada ao mesmo tempo.
- **Commit dentro de laço** que lê e altera a mesma tabela: cada commit libera o undo que o cursor do laço ainda precisa.
- `UNDO_RETENTION` pequeno ou tablespace de undo sem espaço para crescer.

Soluções: tornar a consulta mais rápida, tirar o commit de dentro do laço, aumentar a retenção e o tablespace de undo (tarefa de DBA).

## Relação com Flashback Query

O `AS OF TIMESTAMP` / `AS OF SCN` (seção 02, tópico 13) usa o mesmo mecanismo: pede ao Oracle a fotografia de um momento anterior, montada a partir do undo.

## Documentação oficial

- [Database Concepts — Data Concurrency and Consistency](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/data-concurrency-and-consistency.html)
