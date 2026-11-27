# Colunas virtuais, DEFAULT e colunas invisíveis

## Coluna virtual `[11g+]`

Uma coluna cujo valor é **calculado a partir de outras colunas da mesma linha**, sem ser gravado:

```sql
valor_liquido NUMBER(12,2) GENERATED ALWAYS AS
    (ROUND(quantidade * preco_unitario * (1 - pct_desconto / 100), 2)) VIRTUAL
```

(`GENERATED ALWAYS` e `VIRTUAL` são opcionais: `valor_liquido AS (expressão)` também funciona.)

- Aparece em `SELECT`, `WHERE`, `GROUP BY` como qualquer coluna, mas **não ocupa espaço** e não pode receber valor em `INSERT`/`UPDATE` (ORA-54013).
- Pode ter **índice** (é uma alternativa ao índice baseado em função, com a vantagem de a expressão ter um nome), **constraint** `CHECK`, e servir de chave de particionamento.
- A expressão só pode usar colunas da própria tabela, funções nativas e funções do usuário declaradas `DETERMINISTIC`. Não aceita subquery, sequence, `SYSDATE` nem coluna de outra tabela.
- Com estatísticas coletadas na coluna virtual, o otimizador estima melhor filtros sobre a expressão.

Uso típico: um cálculo repetido em toda consulta (valor líquido, ano da data, documento sem formatação) que passa a ter uma definição única no banco.

## DEFAULT

| Forma | Efeito |
|---|---|
| `DEFAULT expr` | Usado quando a coluna é omitida no `INSERT` |
| `DEFAULT ON NULL expr` `[12c+]` | Usado também quando o valor informado é NULL; a coluna fica `NOT NULL` |
| `DEFAULT seq.NEXTVAL` `[12c+]` | Sequence como valor padrão |
| `DEFAULT SYSDATE`, `DEFAULT USER`, `DEFAULT SYS_CONTEXT(...)` | Data e usuário de criação, sem trigger |

O `DEFAULT` **não** é aplicado num `UPDATE`: para "data da última alteração", é preciso trigger ou a própria aplicação.

## Colunas invisíveis `[12c+]`

```sql
ALTER TABLE t ADD (controle VARCHAR2(20) INVISIBLE);
```

A coluna existe, mas **não aparece** em `SELECT *`, em `DESCRIBE` nem em `INSERT` sem lista de colunas. Só é lida ou gravada quando citada pelo nome. Serve para incluir uma coluna nova sem quebrar código antigo que usa `SELECT *` ou `INSERT ... VALUES` sem lista. `ALTER TABLE t MODIFY (controle VISIBLE)` a torna visível; ela passa a ser a última coluna na ordem.

## Documentação oficial

- [SQL Language Reference — CREATE TABLE (virtual_column_definition)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/CREATE-TABLE.html)
