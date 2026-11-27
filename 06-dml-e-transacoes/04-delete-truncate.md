# DELETE e TRUNCATE

## DELETE

```sql
DELETE FROM itens_pedido WHERE id_pedido = 1007;

DELETE FROM itens_pedido
 WHERE id_pedido IN (SELECT id_pedido FROM pedidos WHERE status = 'CANCELADO');
```

- É DML: participa da transação e pode ser desfeito com `ROLLBACK`.
- Gera undo e redo para **cada linha**, dispara triggers de `DELETE` e verifica as FKs que apontam para a tabela.
- Linhas apagadas liberam espaço dentro dos blocos para novas inserções, mas a tabela não encolhe.
- `[23ai+]` `DELETE FROM destino d FROM origem o WHERE ...` permite join direto; no 19c, use subquery com `IN` ou `EXISTS`, ou uma inline view key-preserved.

## TRUNCATE

```sql
TRUNCATE TABLE tmp_carga;
```

- É **DDL**: faz commit antes e depois, e **não tem rollback**.
- Não apaga linha por linha: desaloca os blocos e reposiciona a marca d'água da tabela. Por isso é quase instantâneo em qualquer volume e devolve o espaço.
- Não dispara triggers de `DELETE`.
- Falha (ORA-02266) se houver **FK habilitada** apontando para a tabela, mesmo com a tabela filha vazia. `TRUNCATE ... CASCADE` `[12c+]` apaga também as filhas, mas só se a FK tiver `ON DELETE CASCADE`.
- Exige ser dono da tabela ou ter o privilégio `DROP ANY TABLE`.

## Comparação

| | `DELETE` | `TRUNCATE` |
|---|---|---|
| Tipo | DML | DDL |
| `WHERE` | Sim | Não: tudo ou nada (ou uma partição) |
| Rollback | Sim | Não |
| Commit implícito | Não | Sim, antes e depois |
| Triggers | Dispara | Não dispara |
| Velocidade em volume | Proporcional ao número de linhas | Constante |
| Espaço | Fica com a tabela | Liberado (salvo `REUSE STORAGE`) |
| FK apontando para a tabela | Verifica linha a linha | Bloqueia o comando |
| Flashback Query depois | Funciona | Não (ORA-01466) |

## Quando usar cada um

- **Tabela de trabalho** (staging, temporária de carga) que é esvaziada toda execução: `TRUNCATE`.
- **Apagar parte dos dados**, ou qualquer coisa em que um erro precise ser desfeito: `DELETE`.
- **Apagar a maior parte de uma tabela grande**: muitas vezes é mais rápido criar uma tabela nova com o que fica (`CREATE TABLE ... AS SELECT`), trocar os nomes e recriar índices e constraints do que fazer um `DELETE` enorme. Ou, com particionamento, `ALTER TABLE ... DROP PARTITION`.

## Armadilhas

- **`DELETE` sem `WHERE`.** Confira com `SELECT COUNT(*)` usando o mesmo `WHERE` antes.
- **`TRUNCATE` no ambiente errado.** Sem rollback, a única volta é backup ou flashback de banco. Confira a conexão antes.
- **`DELETE` em tabela pai com FK sem índice na filha**: bloqueia a tabela filha inteira durante a operação (tópico 08).

## Documentação oficial

- [SQL Language Reference — DELETE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/DELETE.html)
- [SQL Language Reference — TRUNCATE TABLE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/TRUNCATE-TABLE.html)
