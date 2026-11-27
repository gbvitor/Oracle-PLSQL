# UPDATE

## Formas

```sql
-- Simples
UPDATE produtos SET preco_unitario = preco_unitario * 1.05 WHERE id_categoria = 7;

-- Várias colunas
UPDATE clientes SET cidade = 'Palmas', uf = 'TO' WHERE id_cliente = 6;

-- Várias colunas a partir de uma subquery de várias colunas
UPDATE clientes c
   SET (cidade, uf) = (SELECT n.cidade, n.uf FROM novos_enderecos n WHERE n.id_cliente = c.id_cliente)
 WHERE EXISTS (SELECT 1 FROM novos_enderecos n WHERE n.id_cliente = c.id_cliente);
```

## Atualizar a partir de outra tabela

No 19c, há três formas. Todas fazem a mesma coisa quando a origem tem **no máximo uma linha** por linha de destino:

| Forma | Observação |
|---|---|
| `SET col = (subquery correlacionada) WHERE EXISTS (...)` | Funciona sempre; a subquery se repete |
| `MERGE ... WHEN MATCHED THEN UPDATE` | Lê a origem uma vez; a forma preferida para atualização em volume (tópico 05) |
| `UPDATE (SELECT ... FROM destino JOIN origem ...) SET ...` | Inline view atualizável; exige que o destino seja *key-preserved* |

**Key-preserved** significa que cada linha do destino aparece **no máximo uma vez** no resultado do join, o que o Oracle só aceita se a coluna de junção da origem tiver constraint `PRIMARY KEY` ou `UNIQUE`. Sem ela, mesmo que os dados sejam únicos, dá **ORA-01779**.

`[23ai+]` `UPDATE destino d SET ... FROM origem o WHERE d.id = o.id` permite o join direto, como em PostgreSQL e SQL Server.

## O que devolve

`SQL%ROWCOUNT` em PL/SQL, ou a mensagem "n linhas atualizadas" no cliente, informa quantas linhas **casaram com o WHERE**, mesmo que o novo valor seja igual ao antigo. Atualizar uma linha com o mesmo valor ainda gera bloqueio, undo, redo e dispara triggers. Para evitar trabalho inútil, filtre: `WHERE preco_unitario <> :novo_preco`.

## Armadilhas

- **UPDATE sem WHERE.** Atualiza a tabela inteira. Antes de rodar, troque `UPDATE tabela SET ...` por `SELECT COUNT(*) FROM tabela WHERE ...` e confira a quantidade.
- **Subquery sem `WHERE EXISTS`**: linhas sem correspondência recebem NULL (seção 03, tópico 05).
- **Subquery que devolve várias linhas** para a mesma linha de destino: ORA-01427.
- **Atualizar coluna de chave primária** referenciada por FK: falha (ORA-02292) se houver filhos. Chave primária não deve mudar.

## Documentação oficial

- [SQL Language Reference — UPDATE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/UPDATE.html)
