# Arquitetura: instância, memória, processos e arquivos

Um "banco Oracle" em funcionamento são duas coisas separadas:

- **Instância**: memória (SGA e PGAs) e processos em execução num servidor. Existe só enquanto o banco está no ar.
- **Banco de dados** (database): os arquivos em disco (dados, controle, redo). Persistem com o banco parado.

Em RAC, várias instâncias, em servidores diferentes, abrem o mesmo banco.

## Memória

| Área | O que guarda | Visão |
|---|---|---|
| **SGA** (System Global Area) | Memória compartilhada por todas as sessões | `V$SGA`, `V$SGAINFO`, `V$SGA_DYNAMIC_COMPONENTS` |
| Buffer cache | Cópias dos blocos de dados lidos e alterados | |
| Shared pool | SQL e PL/SQL já analisados (cursores, planos), dicionário em cache | |
| Redo log buffer | Alterações a gravar nos redo logs | |
| Large pool, Java pool, Streams pool | Áreas para backup, paralelismo, Java, replicação | |
| **PGA** (Program Global Area) | Memória privada de cada processo de servidor: ordenações, hash joins, variáveis de sessão, coleções PL/SQL | `V$PGASTAT`, `V$PROCESS` |

Parâmetros que dimensionam: `SGA_TARGET`, `PGA_AGGREGATE_TARGET` e `PGA_AGGREGATE_LIMIT`, ou `MEMORY_TARGET` (gerência automática das duas, comum em bancos pequenos).

Relação com o desenvolvimento: coleção PL/SQL enorme (`BULK COLLECT` sem `LIMIT`) cresce na PGA da sessão; SQL sem bind enche o shared pool (seção 11, tópico 01); consulta que ordena muito sem memória suficiente grava em disco temporário (`TEMP`).

## Processos

| Processo | Faz |
|---|---|
| Processos de servidor | Um por sessão (servidor dedicado) ou compartilhados; executam o SQL das sessões |
| `DBWn` (database writer) | Grava blocos alterados do buffer cache nos arquivos de dados, sem pressa |
| `LGWR` (log writer) | Grava o redo log buffer nos redo logs. **No COMMIT**, a sessão espera o LGWR (evento `log file sync`) |
| `CKPT` (checkpoint) | Marca nos arquivos até onde os dados estão gravados |
| `SMON` | Recuperação ao abrir a instância, limpeza de segmentos temporários |
| `PMON` | Limpa sessões que morreram: desfaz a transação e libera os locks |
| `ARCn` | Copia redo logs cheios para os archived logs (em modo `ARCHIVELOG`) |
| `MMON`, `MMNL` | Coletam as estatísticas do AWR (seção 11, tópico 10) |

Por que o COMMIT é rápido mesmo com muitos dados alterados: ele só espera o LGWR gravar o **redo** (pequeno, sequencial); os blocos de dados vão para o disco depois, pelo DBWn. Se a instância cair, o redo permite refazer o que estava confirmado.

## Arquivos

| Arquivo | Conteúdo | Visão |
|---|---|---|
| Arquivos de dados (datafiles) | Tabelas, índices, undo; agrupados em tablespaces (tópico 05) | `DBA_DATA_FILES`, `V$DATAFILE` |
| Arquivos temporários (tempfiles) | Ordenações e hash que não cabem na PGA, tabelas temporárias | `DBA_TEMP_FILES` |
| Control files | Estrutura do banco: nomes dos arquivos, SCN atual, histórico de backups. Sempre multiplexados | `V$CONTROLFILE` |
| Redo logs online | Registro de todas as alterações, em grupos usados em ciclo | `V$LOG`, `V$LOGFILE` |
| Archived logs | Cópias dos redo logs cheios; permitem recuperar até um ponto no tempo | `V$ARCHIVED_LOG` |
| spfile / pfile | Parâmetros de inicialização (tópico 11) | `V$SPPARAMETER` |
| Password file | Senhas de quem conecta `AS SYSDBA` remotamente | `V$PWFILE_USERS` |
| Alert log e traces | Diário da instância (inicializações, erros ORA-00600, deadlocks, mudanças de estrutura) e traces de sessões | `V$DIAG_INFO`, `V$DIAG_ALERT_EXT` |

## Undo e redo, lado a lado

| | Undo | Redo |
|---|---|---|
| Guarda | Os valores **antigos** | As **mudanças** (para refazer) |
| Serve para | ROLLBACK, consistência de leitura, flashback query | Recuperar a instância e o banco depois de falha |
| Onde | Tablespace de undo | Redo logs e archived logs |
| Erro típico | ORA-01555 (*snapshot too old*): o undo necessário para uma leitura longa já foi reaproveitado | `log file sync` alto: COMMIT demais (seção 11, tópico 09) |

## Documentação oficial

- [Database Concepts — Oracle Database Instance](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/oracle-database-instance.html)
- [Database Concepts — Memory Architecture](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/memory-architecture.html)
- [Database Concepts — Process Architecture](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/process-architecture.html)
- [Database Concepts — Physical Storage Structures](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/physical-storage-structures.html)
