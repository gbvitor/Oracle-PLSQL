# Tabelas: CREATE, ALTER, DROP e lixeira

## CREATE TABLE

```sql
CREATE TABLE tabela (
    coluna1  tipo  [DEFAULT expr] [NOT NULL] [constraint inline],
    ...,
    [CONSTRAINT nome tipo (colunas)]
);

-- A partir de uma consulta (CTAS)
CREATE TABLE copia AS SELECT * FROM origem WHERE ...;
```

O `CREATE TABLE ... AS SELECT` copia colunas, tipos e dados, e as constraints `NOT NULL`. **Não copia** chave primária, chaves únicas, FKs, `CHECK`, índices, `DEFAULT`, triggers nem grants. Com `WHERE 1 = 0`, copia só a estrutura.

## ALTER TABLE

| Operação | Comando |
|---|---|
| Incluir coluna | `ALTER TABLE t ADD (col tipo [DEFAULT x] [NOT NULL])` |
| Alterar tipo ou tamanho | `ALTER TABLE t MODIFY (col VARCHAR2(200))` |
| Tornar obrigatória | `ALTER TABLE t MODIFY (col NOT NULL)` (falha se houver nulos) |
| Renomear coluna | `ALTER TABLE t RENAME COLUMN antigo TO novo` |
| Remover coluna | `ALTER TABLE t DROP COLUMN col` |
| Marcar como sem uso (remoção rápida, física depois) | `ALTER TABLE t SET UNUSED COLUMN col` e depois `DROP UNUSED COLUMNS` |
| Renomear tabela | `ALTER TABLE t RENAME TO novo` ou `RENAME t TO novo` |
| Mover / reorganizar | `ALTER TABLE t MOVE [ONLINE]` (invalida índices, exceto com `ONLINE` ou `UPDATE INDEXES`) |
| Somente leitura | `ALTER TABLE t READ ONLY` / `READ WRITE` |

Detalhes:

- `ADD` de coluna com `DEFAULT` e `NOT NULL` é **instantâneo** desde o 11g, mesmo em tabelas enormes: o valor padrão fica no dicionário e não é gravado em cada linha. Desde o 12c, isso vale também para colunas com `DEFAULT` que aceitam nulo.
- Diminuir o tamanho de uma coluna só é aceito se nenhum valor existente passar do novo tamanho; trocar o tipo, em geral, só com a coluna vazia.
- `DROP COLUMN` numa tabela grande reescreve todos os blocos. `SET UNUSED` faz a coluna sumir na hora e adia o trabalho físico.

## DROP TABLE e a lixeira

`DROP TABLE t` não apaga a tabela na hora: ela vai para a **lixeira** (`RECYCLEBIN`) com um nome gerado (`BIN$...`), junto com índices, constraints e triggers. Pode ser recuperada:

```sql
FLASHBACK TABLE t TO BEFORE DROP [RENAME TO outro_nome];
```

| Comando | Efeito |
|---|---|
| `DROP TABLE t` | Vai para a lixeira |
| `DROP TABLE t PURGE` | Apaga de vez, sem lixeira |
| `DROP TABLE t CASCADE CONSTRAINTS` | Remove também as FKs de outras tabelas que apontam para ela |
| `PURGE TABLE t` | Esvazia da lixeira uma tabela já apagada |
| `PURGE RECYCLEBIN` | Esvazia a lixeira do usuário |
| `SELECT * FROM user_recyclebin` | Ver o que está na lixeira |

Recuperada, a tabela volta com os dados; índices e constraints voltam com os nomes `BIN$...` e precisam ser renomeados.

## IF EXISTS / IF NOT EXISTS `[23ai+]`

```sql
CREATE TABLE IF NOT EXISTS t (...);
DROP TABLE IF EXISTS t;
```

No 19c, scripts que precisam rodar mais de uma vez tratam o erro em PL/SQL: `ORA-00942` (não existe) no `DROP`, `ORA-00955` (já existe) no `CREATE`. O padrão está em `00-ambiente/99-remover-schema.sql`.

## Armadilhas

- **CTAS achando que copiou a tabela inteira**: a cópia não tem PK, índices nem FKs.
- **`DROP` sem `PURGE` em tabela grande**: o espaço continua ocupado na lixeira até ser reclamado.
- **Todo DDL faz commit** (seção 01, tópico 10).
- **DDL em tabela com transação aberta de outra sessão**: espera ou falha com ORA-00054.

## Documentação oficial

- [SQL Language Reference — CREATE TABLE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/CREATE-TABLE.html)
- [SQL Language Reference — ALTER TABLE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/ALTER-TABLE.html)
- [SQL Language Reference — FLASHBACK TABLE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/FLASHBACK-TABLE.html)
