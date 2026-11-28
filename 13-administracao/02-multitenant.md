# Multitenant: CDB, PDB e como se conectar a cada um

Desde o 12c, um banco Oracle pode ser um **CDB** (*container database*) que abriga vários **PDBs** (*pluggable databases*). Para a aplicação, cada PDB parece um banco completo e independente: usuários, tabelas, código próprios. Por baixo, todos compartilham a mesma instância (memória e processos) e os mesmos redo logs.

## As peças

| Container | CON_ID | O que é |
|---|---|---|
| `CDB$ROOT` | 1 | Raiz: dicionário do Oracle, usuários comuns. Não guarda dados de aplicação |
| `PDB$SEED` | 2 | Modelo somente leitura usado para criar PDBs novos |
| PDBs (`FREEPDB1`, `VENDAS`, ...) | 3 em diante | Onde ficam os schemas das aplicações |

Arquitetura **não-CDB** (o modelo antigo, um banco = uma instância sem containers) ainda é aceita no 19c, mas não existe mais a partir do 21c. Código e scripts novos devem assumir multitenant.

## Conectar

Cada PDB tem um **serviço** com o próprio nome, registrado no listener:

```text
sqlplus estudo@//localhost:1521/FREEPDB1        no PDB (onde está o schema de estudo)
sqlplus system@//localhost:1521/FREE            no CDB$ROOT
sqlplus / as sysdba                             no servidor: entra no CDB$ROOT
```

Já conectado como usuário comum com privilégio, troca-se de container sem reconectar:

```sql
ALTER SESSION SET CONTAINER = FREEPDB1;
SHOW CON_NAME
```

O erro clássico de quem começa: conectar no serviço do CDB (ou como `/ as sysdba`) e não achar o usuário ou as tabelas, que estão no PDB.

## Usuários comuns e locais

| Tipo | Criado em | Nome | Existe em |
|---|---|---|---|
| **Comum** (*common user*) | `CDB$ROOT` | Prefixo `C##` (`C##ADMIN`) | Todos os containers, com a mesma identidade |
| **Local** | Um PDB | Qualquer nome (`ESTUDO`) | Só naquele PDB |

`SYS` e `SYSTEM` são usuários comuns do Oracle. Usuários de aplicação são locais, criados dentro do PDB.

## Visões

| Visão | Mostra |
|---|---|
| `V$PDBS`, `V$CONTAINERS` | PDBs, estado (`OPEN_MODE`: `READ WRITE`, `MOUNTED`, `READ ONLY`) |
| `CDB_*` | As visões `DBA_*` de todos os containers, com `CON_ID` (consultadas a partir do root) |
| `SYS_CONTEXT('USERENV', 'CON_NAME')`, `'CON_ID'` | Container da sessão |

Dentro de um PDB, as visões `DBA_` e `V$` mostram só aquele PDB (e, para algumas `V$`, os dados compartilhados da instância).

## Operações comuns do DBA

| Operação | Comando |
|---|---|
| Abrir e fechar | `ALTER PLUGGABLE DATABASE vendas OPEN;` / `CLOSE IMMEDIATE;` |
| Abrir sozinho ao subir a instância | `ALTER PLUGGABLE DATABASE vendas SAVE STATE;` |
| Criar a partir do seed | `CREATE PLUGGABLE DATABASE vendas ADMIN USER admin IDENTIFIED BY ...;` |
| Clonar (inclusive de outro CDB, por database link) | `CREATE PLUGGABLE DATABASE vendas_teste FROM vendas;` |
| Desconectar e levar para outro CDB | `ALTER PLUGGABLE DATABASE ... UNPLUG INTO 'arquivo.xml';` e `CREATE PLUGGABLE DATABASE ... USING 'arquivo.xml'` |

Clonar um PDB é a forma mais rápida de criar um ambiente de teste com os dados de produção (com o cuidado de mascarar os dados sensíveis).

## Licenciamento

No 19c Enterprise Edition, até **3 PDBs** de usuário por CDB não exigem a opção Multitenant; acima disso, exige. Standard Edition 2 e as edições gratuitas têm limites próprios. Confira o *Database Licensing Information User Manual* da versão em uso.

## Documentação oficial

- [Multitenant Administrator's Guide — Overview](https://docs.oracle.com/en/database/oracle/oracle-database/19/multi/introduction-to-the-multitenant-architecture.html)
- [Database Concepts — Multitenant Architecture](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/CDBs-and-PDBs.html)
