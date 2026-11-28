# Conexão: string de conexão, EZCONNECT, TNS, CONNECT e DISCONNECT

## Formas de conectar

```text
sqlplus usuario/senha@//host:porta/servico         EZCONNECT
sqlplus usuario/senha@host:porta/servico           EZCONNECT sem as barras
sqlplus usuario/senha@ALIAS                        alias do tnsnames.ora
sqlplus /nolog                                     abre sem conectar; CONNECT depois
sqlplus / as sysdba                                autenticação do sistema operacional (no servidor)
```

| Forma | Precisa de | Quando |
|---|---|---|
| **EZCONNECT** (`//host:porta/servico`) | Nada além do cliente | O mais simples; ambientes de estudo e scripts |
| **EZCONNECT Plus** `[19c+]` (`//host:porta/servico?connect_timeout=10&retry_count=3`) | Cliente 19c+ | Parâmetros de conexão sem `tnsnames.ora` |
| **Alias TNS** | Arquivo `tnsnames.ora` na pasta indicada por `TNS_ADMIN` (ou `$ORACLE_HOME/network/admin`) | Ambientes de empresa com vários bancos, failover, RAC |
| **Wallet** | Carteira com as credenciais (`mkstore`, ou a baixada do Autonomous Database) | Conectar sem senha no script; obrigatório no Autonomous |

No container do Oracle Free usado na seção 00:

```text
sqlplus estudo@//localhost:1521/FREEPDB1
```

O serviço é o nome do **PDB** (`FREEPDB1`), não o SID da instância (`FREE`). Conectar no serviço do CDB leva ao container raiz, onde o usuário de estudo não existe (ORA-01017).

## A senha fora da linha de comando

`sqlplus estudo/Estudo#2026@...` deixa a senha visível no histórico do shell e na lista de processos (`ps`) para outros usuários da máquina. Prefira:

```text
sqlplus estudo@//localhost:1521/FREEPDB1           o SQL*Plus pergunta a senha
sqlplus /nolog                                     e dentro: CONNECT estudo@//localhost:1521/FREEPDB1
```

Senha com caracteres especiais (`#`, `@`, `$`, `!`) precisa de aspas duplas: `CONNECT estudo/"Estudo#2026"@...`. No shell, as aspas também precisam ser protegidas (`'"Estudo#2026"'`).

## Dentro da sessão

| Comando | Faz |
|---|---|
| `CONNECT usuario@conexao` (ou `CONN`) | Troca de conexão; a transação aberta da conexão anterior recebe **COMMIT** |
| `DISCONNECT` (ou `DISC`) | Desconecta (com COMMIT) e continua no SQL*Plus |
| `EXIT` / `QUIT` | Sai; por padrão com COMMIT (`EXIT ROLLBACK` para desfazer) |
| `SHOW USER` | Usuário conectado |
| `SHOW CON_NAME` `[12c+]` | Container (PDB) atual |
| `PASSWORD` | Troca a senha sem mostrá-la na tela |

O COMMIT implícito no `CONNECT`, no `DISCONNECT` e no `EXIT` surpreende: um UPDATE de teste esquecido é confirmado ao sair. `SET EXITCOMMIT OFF` `[11g+]` muda o `EXIT` para ROLLBACK.

## Erros comuns

| Erro | Causa provável |
|---|---|
| ORA-12154 | Alias TNS não encontrado: `TNS_ADMIN` errado ou alias com outro nome |
| ORA-12514 | O listener não conhece o serviço pedido: nome do serviço errado ou PDB fechado |
| ORA-12541 | Nenhum listener na porta: banco parado, porta errada ou container sem a porta publicada |
| ORA-01017 | Usuário ou senha errados, ou conectado no container errado (CDB em vez de PDB) |
| ORA-28000 / ORA-28001 | Conta bloqueada / senha expirada |

## Documentação oficial

- [SQL*Plus User's Guide — Connecting to a Database](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/connecting-to-database.html)
- [Net Services Administrator's Guide — Easy Connect Naming](https://docs.oracle.com/en/database/oracle/oracle-database/19/netag/configuring-naming-methods.html)
