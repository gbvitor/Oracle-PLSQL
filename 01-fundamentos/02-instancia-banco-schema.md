# Instância, banco, schema e usuário

No dia a dia esses termos são usados como sinônimos, mas no Oracle cada um é uma coisa diferente. Confundir os quatro gera erro de conexão ("conectei no banco errado") e de permissão ("a tabela existe, mas não aparece").

## Instância e banco de dados

**Banco de dados** é o conjunto de arquivos em disco: arquivos de dados, arquivos de controle e arquivos de redo. É onde a informação fica guardada.

**Instância** é o que está em memória e em execução: a área de memória compartilhada (SGA) e os processos de fundo que leem e gravam aqueles arquivos. Quando o servidor desliga, a instância some e o banco continua no disco.

Uma instância abre um banco. Em ambiente RAC (cluster), várias instâncias abrem o mesmo banco ao mesmo tempo.

## Multitenant: CDB e PDB

Desde o 12c, um banco Oracle pode ser um **contêiner (CDB)** que hospeda vários **bancos plugáveis (PDBs)**. Para a aplicação, cada PDB se comporta como um banco independente, com seus próprios usuários e tabelas. A partir do 21c, essa é a única arquitetura suportada; no 19c ainda existe o modelo antigo (non-CDB), embora já fosse considerado obsoleto.

| Contêiner | Para que serve | No Oracle Free |
|---|---|---|
| `CDB$ROOT` | Metadados do Oracle e usuários comuns (`C##...`); não recebe dados de aplicação | Serviço `FREE` |
| `PDB$SEED` | Modelo somente leitura usado para criar PDBs novos | — |
| PDB de aplicação | Onde ficam usuários, tabelas e código | Serviço `FREEPDB1` |

Por isso a conexão de estudo usa `localhost:1521/FREEPDB1`, e não `.../FREE`. Conectado no CDB raiz, `CREATE USER estudo` falha com ORA-65096, porque ali só se criam usuários comuns, com prefixo `C##`.

## Usuário e schema

No Oracle, **usuário** é a conta que se conecta e **schema** é o conjunto de objetos que pertencem a ela. Cada usuário tem exatamente um schema, com o mesmo nome. Criar o usuário `estudo` cria o schema `estudo`.

Consequências práticas:

- `SELECT * FROM clientes` procura `clientes` no schema do usuário conectado. Para ler a tabela de outro schema: `SELECT * FROM outro_usuario.clientes`, e só funciona se houver `GRANT SELECT` para quem consulta.
- `ALTER SESSION SET CURRENT_SCHEMA = outro_usuario` muda o schema padrão da sessão para resolução de nomes, mas não dá privilégio nenhum.
- Sistemas costumam ter um **usuário dono** (que só guarda os objetos) e **usuários de aplicação** que acessam por grant e synonym.
- Desde o 18c existe usuário sem senha (`CREATE USER ... NO AUTHENTICATION`), que só serve para guardar objetos e não aceita login direto.

## Como saber onde você está

```sql
SELECT SYS_CONTEXT('USERENV', 'CON_NAME')       AS container,
       SYS_CONTEXT('USERENV', 'SESSION_USER')   AS usuario,
       SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') AS schema_atual,
       SYS_CONTEXT('USERENV', 'DB_NAME')        AS banco,
       SYS_CONTEXT('USERENV', 'INSTANCE_NAME')  AS instancia
  FROM dual;
```

## Armadilhas

- **ORA-00942 (tabela ou view não existe)** nem sempre significa que a tabela não existe. Também aparece quando ela está em outro schema sem o prefixo, ou quando falta o grant.
- **Conexão no CDB raiz por engano.** Tudo parece funcionar até a primeira criação de usuário ou tabela.
- **Privilégio via role dentro de PL/SQL.** Grants recebidos por role não valem dentro de procedure armazenada com `AUTHID DEFINER` (o padrão). A consulta funciona no editor e falha dentro da procedure. Detalhes na seção 09.

## Documentação oficial

- [Database Concepts — Oracle Database Instance](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/oracle-database-instance.html)
- [Multitenant Administrator's Guide 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/multi/index.html)
