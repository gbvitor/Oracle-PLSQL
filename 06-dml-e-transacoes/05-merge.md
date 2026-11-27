# MERGE

## O que faz

Compara uma **origem** com um **destino** e, numa instrução só, atualiza as linhas que já existem e insere as que não existem. É o "upsert" do Oracle e a forma padrão de sincronizar tabelas e fazer carga incremental.

```sql
MERGE INTO produtos d
USING (SELECT id_produto, preco FROM tabela_precos_nova) o
   ON (d.id_produto = o.id_produto)
 WHEN MATCHED THEN
      UPDATE SET d.preco_unitario = o.preco
 WHEN NOT MATCHED THEN
      INSERT (id_produto, preco_unitario, ...) VALUES (o.id_produto, o.preco, ...);
```

## Partes

| Parte | Papel |
|---|---|
| `INTO destino` | A tabela que será alterada |
| `USING origem` | Tabela, view ou subquery com os dados novos |
| `ON (condição)` | Como saber se a linha da origem já existe no destino; os parênteses são obrigatórios |
| `WHEN MATCHED THEN UPDATE ... [WHERE ...]` | O que fazer quando existe; o `WHERE` opcional filtra quais atualizar |
| `[DELETE WHERE ...]` | Depois do `UPDATE`, apaga as linhas atualizadas que atendem a condição |
| `WHEN NOT MATCHED THEN INSERT ... [WHERE ...]` | O que fazer quando não existe |

As duas cláusulas `WHEN` são opcionais desde o 10g: um `MERGE` só com `WHEN MATCHED` é uma forma eficiente de "UPDATE a partir de outra tabela" (tópico 03).

## Regras

- **Uma linha do destino só pode casar com uma linha da origem.** Se duas linhas da origem casarem com a mesma linha do destino, o Oracle não sabe qual aplicar e dá **ORA-30926** (não foi possível obter um conjunto estável de linhas). Garanta unicidade na origem, agregando ou deduplicando antes.
- **As colunas do `ON` não podem ser atualizadas** no `UPDATE SET` (ORA-38104).
- O `DELETE WHERE` só age sobre as linhas que **foram atualizadas** pelo `MERGE`, e avalia a condição com os valores **depois** do `UPDATE`.
- A contagem de linhas devolvida é a soma de atualizadas, inseridas e apagadas.

## Evitar atualização inútil

Sem filtro, o `WHEN MATCHED` atualiza toda linha que casa, mesmo que nada tenha mudado, com o custo de undo, redo, bloqueio e triggers. Em carga incremental, compare antes:

```sql
WHEN MATCHED THEN UPDATE SET d.preco_unitario = o.preco
                  WHERE DECODE(d.preco_unitario, o.preco, 0, 1) = 1
```

`DECODE` trata NULL = NULL, então a comparação também funciona com colunas opcionais.

## Documentação oficial

- [SQL Language Reference — MERGE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/MERGE.html)
