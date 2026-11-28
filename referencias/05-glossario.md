# Glossário

Termos usados no repositório, com a seção onde aparecem em detalhe.

| Termo | Significado | Onde |
|---|---|---|
| **ACID** | Atomicidade, consistência, isolamento e durabilidade: as garantias de uma transação | 14/02 |
| **AUTHID** | Cláusula que define com os privilégios de quem a rotina roda: do dono (`DEFINER`, padrão) ou de quem chama (`CURRENT_USER`) | 09/14 |
| **AWR / ASH** | Repositório de estatísticas de desempenho por intervalo / amostras da atividade das sessões a cada segundo. Exigem o Diagnostics Pack (licença) | 11/10 |
| **Backtrace** | Pilha que mostra a linha onde um erro foi levantado, mesmo depois de tratado e relançado (`DBMS_UTILITY.FORMAT_ERROR_BACKTRACE`) | 09/13 |
| **Bind variable** | Valor passado à parte do texto do SQL (`:v`). Permite reaproveitar o plano e impede injeção | 11/07, 12/04 |
| **Bloco anônimo** | Trecho PL/SQL `DECLARE ... BEGIN ... END;` sem nome, executado uma vez e não guardado no banco | 08/01 |
| **Buffer cache** | Área da SGA com cópias dos blocos de dados lidos | 13/01 |
| **BULK COLLECT / FORALL** | Leitura e escrita em lote entre PL/SQL e SQL, reduzindo trocas de contexto | 09/08 |
| **Cardinalidade** | Número estimado de linhas que uma etapa do plano devolve | 11/04 |
| **CBO** | Otimizador baseado em custo: escolhe o plano estimando o custo de cada alternativa a partir das estatísticas | 11/01 |
| **CDB / PDB** | Banco contêiner / banco plugável. Desde o 12c, um CDB contém vários PDBs; a aplicação conecta no PDB | 13/02 |
| **Chave primária / única / estrangeira** | Identifica a linha / impede repetição / aponta para a chave de outra tabela | 07/02 |
| **Coleção** | Variável PL/SQL com vários elementos: associative array, nested table, varray | 09/07 |
| **Coluna virtual** | Coluna calculada por expressão, sem armazenamento | 07/09 |
| **Commit implícito** | `COMMIT` que o Oracle faz antes e depois de toda DDL | 06/06 |
| **Compound trigger** | Trigger com seções para antes e depois do comando e de cada linha, com estado compartilhado | 09/05 |
| **Concorrência otimista** | Não travar ao ler; ao gravar, conferir (por versão) que ninguém alterou no meio | 16/05 |
| **Consistência de leitura** | Cada consulta vê os dados como estavam no início dela, sem ser bloqueada por quem altera | 06/07 |
| **Constraint** | Regra declarada na tabela: `NOT NULL`, `CHECK`, `UNIQUE`, `PRIMARY KEY`, `FOREIGN KEY` | 07/02 |
| **CTE** | Subconsulta nomeada na cláusula `WITH`; recursiva quando referencia a si mesma | 02/08 |
| **Cursor** | Área que guarda uma consulta em execução e a posição de leitura; implícito (o Oracle gerencia) ou explícito | 08/06 a 08/08 |
| **Data Pump** | Exportação e importação lógicas (`expdp`/`impdp`) | 13/10 |
| **DCL / DDL / DML / TCL** | Comandos de privilégio (`GRANT`) / de estrutura (`CREATE`) / de dados (`INSERT`) / de transação (`COMMIT`) | 01/10 |
| **Deadlock** | Duas sessões esperando uma pela outra; o Oracle detecta e desfaz a instrução de uma (ORA-00060) | 06/08 |
| **DETERMINISTIC** | Declara que a function devolve sempre o mesmo resultado para a mesma entrada | 09/02 |
| **Dicionário de dados** | Tabelas e visões do próprio banco que descrevem os objetos (`USER_`, `ALL_`, `DBA_`, `V$`) | 10 |
| **Dimensão / fato** | Na modelagem analítica: tabela de contexto (tempo, produto) / tabela de medidas (vendas) | 14/04 |
| **DIRECTORY** | Objeto que aponta para uma pasta do servidor, usado por `UTL_FILE` e Data Pump | 15/10 |
| **DUAL** | Tabela de uma linha e uma coluna, para `SELECT` de expressão | 01/05 |
| **Edição (EBR)** | Edition-Based Redefinition: versões de código PL/SQL e views convivendo, para atualizar sem parar | 09/15 |
| **Estatísticas** | Medidas das tabelas, colunas e índices (linhas, valores distintos, histogramas) que o otimizador usa | 11/05 |
| **Exceção** | Erro em PL/SQL; pré-definida (`NO_DATA_FOUND`), nomeada com `EXCEPTION_INIT`, ou de aplicação (−20000 a −20999) | 08/09 |
| **Explain plan** | Plano *estimado*; `DBMS_XPLAN.DISPLAY_CURSOR` mostra o plano *usado* | 11/02, 11/03 |
| **Fetch across commit** | `COMMIT` dentro do laço de um cursor ainda aberto; risco de ORA-01555 | 15/11 |
| **Flashback** | Consultar ou restaurar dados como estavam antes, usando o undo (`AS OF TIMESTAMP`, `FLASHBACK TABLE`) | 13/09 |
| **Full table scan** | Leitura de todos os blocos da tabela; não é sempre ruim | 11/06 |
| **Hard parse / soft parse** | Compilar o SQL do zero e gerar plano / reaproveitar o cursor já compilado | 11/01 |
| **Hint** | Comentário `/*+ ... */` que orienta o otimizador | 11/08 |
| **Histograma** | Estatística da distribuição de valores de uma coluna, para dados desbalanceados | 11/05 |
| **Identity** | Coluna numerada automaticamente `[12c+]`; por baixo, uma sequence | 07/07 |
| **Idempotente** | Operação que pode ser repetida sem efeito adicional | 15/07 |
| **Índice B-tree / bitmap / baseado em função** | Árvore ordenada (o padrão) / mapa de bits, para baixa cardinalidade em DW / sobre expressão (`UPPER(nome)`) | 07/04 |
| **Índice único parcial** | No Oracle, índice único sobre `CASE WHEN condição THEN coluna END`: só as linhas da condição entram | 16/02 |
| **Injeção de SQL** | Texto do usuário concatenado no SQL e executado como comando | 09/09 |
| **Instância / banco** | Processos e memória / arquivos em disco | 01/02, 13/01 |
| **Isolamento** | Quanto uma transação enxerga das outras; o Oracle tem `READ COMMITTED` (padrão) e `SERIALIZABLE` | 06/09 |
| **Junção (join)** | Combinação de linhas de duas tabelas por uma condição | 05 |
| **Kardex** | Histórico de movimentos de estoque com o saldo depois de cada um | 16/01 |
| **Lateral / APPLY** | Subconsulta no `FROM` que pode referenciar a tabela à esquerda `[12c+]` | 05/10 |
| **Library cache** | Parte da shared pool com SQL e PL/SQL compilados | 13/01 |
| **Listener** | Processo que recebe as conexões de rede e as entrega à instância | 12/01 |
| **Lock (trava)** | Reserva de linha (TX) ou de tabela (TM) até o fim da transação | 06/08, 13/07 |
| **Lost update** | Uma gravação apagando outra feita depois da leitura, sem perceber | 16/05 |
| **Materialized view** | View com o resultado armazenado, atualizada sob demanda ou por log | 07/06 |
| **MERGE** | Inserir ou atualizar conforme exista ou não (upsert) | 06/05 |
| **Multitenant** | Arquitetura CDB/PDB | 13/02 |
| **MVCC** | Controle de concorrência por versões: leitura vê versão anterior em vez de esperar | 14/02 |
| **Mutante (tabela)** | Tabela sendo alterada pelo comando que disparou o trigger de linha; não pode ser lida nele (ORA-04091) | 09/05 |
| **NLS** | Parâmetros de idioma e território: formato de data, separador decimal, ordenação | 13/11 |
| **Normalização** | Organizar tabelas para que cada fato fique num lugar só (1FN, 2FN, 3FN) | 14/03 |
| **NULL** | Ausência de valor; comparação com NULL é desconhecida, não falsa | 01/04, 03/08 |
| **OLTP / OLAP** | Sistema transacional (muitas operações pequenas) / analítico (consultas grandes sobre histórico) | 14/04 |
| **Package** | Unidade PL/SQL com especificação (pública) e corpo (implementação), com estado por sessão | 09/03 |
| **Paginação** | Devolver o resultado em páginas: `OFFSET/FETCH` ou por chave (*keyset*) | 14/07 |
| **Particionamento** | Dividir uma tabela em partes por faixa, lista ou hash, transparentes para a consulta | 07/11 |
| **PGA** | Memória privada de cada processo do servidor: ordenações, hash, variáveis PL/SQL | 13/01 |
| **Pipelined function** | Function que devolve linhas uma a uma para um `SELECT ... FROM TABLE(f())` | 09/11 |
| **Plano de execução** | Sequência de operações que o Oracle usa para executar um SQL | 11/04 |
| **PRAGMA** | Instrução ao compilador: `AUTONOMOUS_TRANSACTION`, `EXCEPTION_INIT`, `UDF`, `SERIALLY_REUSABLE` | 09 |
| **Predicado de acesso / filtro** | Condição usada para chegar às linhas (índice) / aplicada depois de lê-las | 11/04 |
| **Pseudocoluna** | Valor que parece coluna sem ser: `ROWNUM`, `ROWID`, `LEVEL`, `NEXTVAL` | 01/06 |
| **Redo / undo** | Registro para refazer alterações (recuperação) / dados anteriores, para desfazer e para leitura consistente | 13/01 |
| **REF CURSOR** | Variável que aponta para um cursor aberto; passa resultado entre rotinas e para a aplicação | 09/10 |
| **Role** | Conjunto de privilégios concedido como um só; desativado dentro de PL/SQL de direitos do dono | 13/04 |
| **ROWID** | Endereço físico da linha; o acesso mais rápido a uma linha | 01/06 |
| **Savepoint** | Marca dentro da transação para desfazer só a parte posterior | 06/06 |
| **Schema** | Conjunto de objetos de um usuário | 01/02 |
| **Sequence** | Gerador de números únicos; pode ter buracos | 07/07 |
| **SGA** | Memória compartilhada da instância: buffer cache, shared pool, redo log buffer | 13/01 |
| **Shared pool** | Parte da SGA com o dicionário em cache e o library cache | 13/01 |
| **SID / serial#** | Identificação da sessão (o par identifica de forma única ao longo do tempo) | 13/06 |
| **Sinônimo** | Nome alternativo para um objeto, inclusive de outro schema | 07/08 |
| **SQL*Plus / SQLcl** | Clientes de linha de comando: o clássico / o moderno, em Java | 12 |
| **Staging** | Tabela intermediária que recebe a carga bruta antes de validar e aplicar | 15/07 |
| **Subconsulta correlacionada** | Subconsulta que referencia a linha da consulta de fora | 05/05 |
| **Tablespace** | Unidade lógica de armazenamento, formada por arquivos de dados | 13/05 |
| **Tabela temporária global** | Tabela de estrutura permanente e dados por sessão ou por transação | 07/10 |
| **Top-N** | As N primeiras linhas por um critério, no geral ou por grupo | 05/07 |
| **Transação autônoma** | Transação independente dentro de outra; confirma sem confirmar a principal | 09/12 |
| **Trigger** | Código executado automaticamente num evento: DML, DDL, logon | 09/04 |
| **utPLSQL** | Framework de testes unitários para PL/SQL, com anotações e relatórios | 09/17, 16/05 |
| **V$** | Visões dinâmicas de desempenho: o estado atual da instância (sessões, SQL, esperas) | 10/09 |
| **View** | Consulta guardada com nome, usada como tabela | 07/05 |
| **Wait event** | O que uma sessão está esperando: I/O, trava, rede | 13/06 |

As referências estão no formato `seção/tópico`: `09/14` é `09-plsql-avancado/14-authid.md`.
