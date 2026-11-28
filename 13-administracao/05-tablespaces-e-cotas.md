# Tablespaces e cotas

**Tablespace** é a unidade lógica de armazenamento: um nome (`USERS`, `DADOS_VENDAS`) associado a um ou mais arquivos de dados. Toda tabela e todo índice moram num tablespace; o espaço de cada um é um **segmento**, formado por **extents**, formados por **blocos** (normalmente de 8 KB).

## Tipos

| Tipo | Guarda | Exemplos |
|---|---|---|
| Permanente | Tabelas, índices, LOBs | `SYSTEM`, `SYSAUX` (do Oracle), `USERS` e os da aplicação |
| Temporário | Ordenações, hash joins e tabelas temporárias que não cabem na memória | `TEMP` |
| Undo | Valores antigos para ROLLBACK e consistência de leitura | `UNDOTBS1` |

`SYSTEM` e `SYSAUX` são só do Oracle: objetos de aplicação ali atrapalham manutenção e backup.

## Criar e crescer

```sql
CREATE TABLESPACE dados_vendas
    DATAFILE '/opt/oracle/oradata/FREE/FREEPDB1/dados_vendas01.dbf' SIZE 500M
    AUTOEXTEND ON NEXT 100M MAXSIZE 10G;

ALTER DATABASE DATAFILE '/.../dados_vendas01.dbf' RESIZE 1G;
ALTER TABLESPACE dados_vendas ADD DATAFILE '/.../dados_vendas02.dbf' SIZE 500M AUTOEXTEND ON;
```

- Com **OMF** (`DB_CREATE_FILE_DEST` definido), o Oracle escolhe nome e local: `CREATE TABLESPACE dados_vendas;` basta.
- **Smallfile** (padrão) tem até 1022 arquivos de até 32 GB (bloco de 8 KB); **bigfile**, um arquivo só, de até 32 TB.
- `AUTOEXTEND ON` sem `MAXSIZE` cresce até encher o disco. Em produção, sempre com limite e monitoramento.

## Cotas

O usuário só ocupa espaço num tablespace se tiver **cota** nele (ou o privilégio `UNLIMITED TABLESPACE`, que dá cota ilimitada em todos, inclusive `SYSTEM`: evite).

```sql
ALTER USER vendas QUOTA 2G ON dados_vendas;
ALTER USER vendas QUOTA UNLIMITED ON dados_vendas;
ALTER USER vendas QUOTA 0 ON users;
```

Com `DEFERRED_SEGMENT_CREATION` (padrão desde o 11gR2), uma tabela vazia não ocupa espaço: o erro de cota aparece só no primeiro `INSERT`, não no `CREATE TABLE`.

## Erros de espaço

| Erro | Significa | Ação |
|---|---|---|
| ORA-01950 | Sem cota no tablespace | `ALTER USER ... QUOTA` |
| ORA-01536 | Cota estourada | Aumentar a cota ou liberar espaço |
| ORA-01653 / ORA-01654 | Tablespace cheio: não há onde criar o próximo extent da tabela / do índice | Aumentar arquivo, ligar `AUTOEXTEND`, acrescentar arquivo |
| ORA-01652 | Tablespace temporário cheio | Consulta que ordena demais (revisar o SQL) ou `TEMP` pequeno |
| ORA-30036 / ORA-01555 | Undo sem espaço / undo já reaproveitado para uma leitura longa | Undo maior, `UNDO_RETENTION`, transações e consultas menores |

## Espaço que não volta

Apagar linhas (`DELETE`) não devolve espaço ao tablespace: os blocos ficam livres **para a mesma tabela**. Para devolver: `TRUNCATE` (tabela inteira), `ALTER TABLE ... MOVE` (reconstrói; índices ficam UNUSABLE até `REBUILD`, ou `MOVE ONLINE` `[12.2+]`), ou `ALTER TABLE ... SHRINK SPACE` (exige `ENABLE ROW MOVEMENT`). Arquivo de dados só diminui com `RESIZE` se o espaço livre estiver no fim dele.

## Documentação oficial

- [Database Administrator's Guide — Managing Tablespaces](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/managing-tablespaces.html)
- [Database Concepts — Logical Storage Structures](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/logical-storage-structures.html)
