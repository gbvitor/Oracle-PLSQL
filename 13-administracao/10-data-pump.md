# Data Pump: expdp e impdp

Data Pump exporta e importa objetos e dados num formato binário próprio (arquivos `.dmp`). É a ferramenta para copiar um schema entre bancos, levar dados de produção para teste, guardar uma cópia lógica antes de uma mudança grande ou migrar de versão.

Não é backup do banco: para recuperar o banco depois de uma falha, o caminho é o RMAN. Data Pump é cópia **lógica**, de objetos escolhidos, num momento.

## Onde ficam os arquivos

Os arquivos são gravados **no servidor do banco**, numa pasta representada por um objeto `DIRECTORY`:

```sql
CREATE OR REPLACE DIRECTORY dp_dir AS '/opt/oracle/dpdump';
GRANT READ, WRITE ON DIRECTORY dp_dir TO estudo;
```

Todo banco tem o `DATA_PUMP_DIR` pronto (usado se nenhum for informado), mas em geral só o DBA tem acesso a ele.

## Exportar

```text
expdp estudo@//localhost:1521/FREEPDB1 schemas=ESTUDO directory=dp_dir dumpfile=estudo_%U.dmp logfile=estudo_exp.log
```

| Parâmetro | Para |
|---|---|
| `SCHEMAS=a,b` / `TABLES=t1,t2` / `FULL=Y` | O que exportar (o modo) |
| `INCLUDE=TABLE:"IN ('CLIENTES','PEDIDOS')"` / `EXCLUDE=STATISTICS` | Filtrar tipos e nomes de objetos |
| `QUERY=pedidos:"WHERE data_pedido >= DATE '2026-01-01'"` | Exportar só parte das linhas |
| `CONTENT=METADATA_ONLY` / `DATA_ONLY` | Só estrutura ou só dados |
| `FLASHBACK_TIME=SYSTIMESTAMP` | Exportação consistente: todas as tabelas no mesmo instante |
| `PARALLEL=4` + `dumpfile=..._%U.dmp` | Vários processos e arquivos (**Enterprise Edition**) |
| `COMPRESSION=METADATA_ONLY` | Padrão; `ALL` ou `DATA_ONLY` exigem a opção **Advanced Compression** |
| `PARFILE=arquivo.par` | Parâmetros num arquivo: evita o inferno de aspas da linha de comando |

**Sempre** `FLASHBACK_TIME` (ou `FLASHBACK_SCN`) ao exportar um schema em uso: sem isso, cada tabela é exportada num momento diferente e as FKs podem não fechar.

## Importar

```text
impdp system@//servidor/PDB_TESTE directory=dp_dir dumpfile=estudo_%U.dmp remap_schema=ESTUDO:ESTUDO_TESTE
```

| Parâmetro | Para |
|---|---|
| `REMAP_SCHEMA=origem:destino` | Importar com outro nome de schema (cria o usuário, se o import tiver privilégio para isso) |
| `REMAP_TABLESPACE=origem:destino` | Tablespace diferente no destino |
| `TABLE_EXISTS_ACTION=SKIP\|APPEND\|TRUNCATE\|REPLACE` | O que fazer se a tabela já existir (padrão `SKIP`) |
| `SQLFILE=ddl.sql` | **Não importa nada**: gera o arquivo com todo o DDL que seria executado. Ótimo para revisar ou extrair DDL de um dump |
| `TRANSFORM=SEGMENT_ATTRIBUTES:N` | Ignorar storage e tablespace do dump |
| `NETWORK_LINK=dblink` | Importar direto de outro banco, sem arquivo intermediário |

## Privilégios

- Qualquer usuário exporta e importa **o próprio schema** (com acesso ao DIRECTORY).
- Para outros schemas, `FULL`, ou `REMAP_SCHEMA` criando usuário: roles `DATAPUMP_EXP_FULL_DATABASE` e `DATAPUMP_IMP_FULL_DATABASE`.

## Acompanhar e controlar

O job roda **no servidor**: fechar o terminal não interrompe. `expdp ... attach=nome_do_job` reconecta para ver o estado, pausar (`STOP_JOB`), retomar (`START_JOB`) ou cancelar (`KILL_JOB`). Visões: `DBA_DATAPUMP_JOBS`, `USER_DATAPUMP_JOBS`, `V$SESSION_LONGOPS`.

A mesma funcionalidade existe em PL/SQL, pela package `DBMS_DATAPUMP`: útil para exportação agendada por `DBMS_SCHEDULER`, sem acesso ao sistema operacional.

## exp e imp `[legado]`

Os utilitários antigos (`exp`/`imp`) ainda existem para ler arquivos de bancos muito antigos, mas não suportam recursos novos. Arquivos `.dmp` de `exp` não são lidos pelo `impdp`, e vice-versa.

## Documentação oficial

- [Utilities — Oracle Data Pump](https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil/oracle-data-pump.html)
- [Utilities — Data Pump Export Parameters](https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil/oracle-data-pump-export-utility.html)
- [PL/SQL Packages and Types Reference — DBMS_DATAPUMP](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_DATAPUMP.html)
