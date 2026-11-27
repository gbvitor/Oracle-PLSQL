# INSERT ALL e INSERT FIRST

Inserem em **várias tabelas** (ou várias vezes na mesma) a partir de uma única leitura da origem.

## Formas

```sql
-- Incondicional: toda linha da origem vai para todos os destinos
INSERT ALL
    INTO destino_a (c1, c2) VALUES (x, y)
    INTO destino_b (c1)     VALUES (x)
SELECT x, y FROM origem;

-- Condicional ALL: a linha vai para TODOS os destinos cuja condição for verdadeira
INSERT ALL
    WHEN valor > 10000      THEN INTO grandes   VALUES (...)
    WHEN status = 'ENTREGUE' THEN INTO entregues VALUES (...)
    ELSE                          INTO outros    VALUES (...)
SELECT ... FROM origem;

-- Condicional FIRST: a linha vai só para o PRIMEIRO destino cuja condição for verdadeira
INSERT FIRST
    WHEN valor > 10000       THEN INTO grandes   VALUES (...)
    WHEN status = 'ENTREGUE' THEN INTO entregues VALUES (...)
    ELSE                          INTO outros    VALUES (...)
SELECT ... FROM origem;
```

No `INSERT ALL` condicional, uma linha que atende duas condições é inserida duas vezes; o `ELSE` só recebe as que não atendem nenhuma. No `INSERT FIRST`, cada linha vai para um destino só, como num `CASE`.

## Usos

- **Distribuir uma carga** em tabelas por tipo, período ou situação, lendo a origem uma vez.
- **Transformar colunas em linhas** (o contrário do pivot): várias cláusulas `INTO` na mesma tabela, uma por coluna.
- **Várias linhas literais no 19c**: `INSERT ALL INTO t VALUES (...) INTO t VALUES (...) SELECT * FROM dual`.

## Regras e armadilhas

- O `SELECT` da origem é obrigatório, mesmo que seja `SELECT * FROM dual`.
- **Sequence no `INSERT ALL`**: `seq.NEXTVAL` em várias cláusulas `INTO` devolve **o mesmo valor** para uma linha da origem, porque o `NEXTVAL` é avaliado uma vez por linha lida, não por linha inserida. Para gerar chaves distintas em cada destino, use colunas `IDENTITY` ou sequences diferentes.
- Não aceita `RETURNING`.
- Não pode inserir numa view nem em tabela remota.
- O número de linhas afetadas informado é o total de inserções em todos os destinos.

## Documentação oficial

- [SQL Language Reference — INSERT (multi_table_insert)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/INSERT.html)
