# 00 — Ambiente

Onde rodar os exemplos e como preparar o schema que todo o repositório usa.

## Arquivos

| Arquivo | Para que serve |
|---|---|
| [modelo-de-dados.md](modelo-de-dados.md) | Diagrama, tabelas, regras e casos de borda do schema de exemplo |
| [01-criar-usuario.sql](01-criar-usuario.sql) | Cria o usuário `estudo` (rodar como SYSTEM; não se aplica ao FreeSQL) |
| [02-criar-schema.sql](02-criar-schema.sql) | Cria as sete tabelas, índices e comentários |
| [03-carregar-dados.sql](03-carregar-dados.sql) | Insere os dados fictícios |
| [04-conferir-carga.sql](04-conferir-carga.sql) | Confere contagens e totais; tudo deve sair `OK` |
| [99-remover-schema.sql](99-remover-schema.sql) | Apaga as tabelas do schema de exemplo |
| [instalar.sql](instalar.sql) | Roda 99, 02, 03 e 04 em sequência (SQL*Plus / SQLcl) |

## Opção 1 — FreeSQL (navegador, sem instalar nada)

[FreeSQL](https://freesql.com/) é o ambiente gratuito da Oracle que substituiu o Live SQL. Roda Oracle 26ai.

1. Entre com uma conta Oracle (gratuita). Sem login, só é possível consultar os schemas de amostra; criar tabela exige login.
2. Cole e execute, um de cada vez: `02-criar-schema.sql`, `03-carregar-dados.sql`, `04-conferir-carga.sql`.
3. Para recomeçar do zero, rode `99-remover-schema.sql` e repita o passo 2.

Limitações: não dá para usar comandos de SQL*Plus (`@`, `SPOOL`, `COLUMN`), nem visões de administração (V$, DBA_), nem criar usuários. As seções 10, 11, 12 e 13 rendem mais no ambiente local.

## Opção 2 — Oracle AI Database Free em container (recomendado)

Banco completo na sua máquina, com acesso de administrador. Requer Docker ou Podman.

### Subir o banco

```bash
docker run -d --name oracle-free \
  -p 1521:1521 \
  -e ORACLE_PWD='Oracle#2026' \
  -v oracle-free-data:/opt/oracle/oradata \
  container-registry.oracle.com/database/free:latest
```

- `ORACLE_PWD` define a senha de SYS, SYSTEM e PDBADMIN.
- O volume `oracle-free-data` mantém os dados quando o container é recriado.
- A primeira inicialização leva alguns minutos. Acompanhe com `docker logs -f oracle-free` até aparecer `DATABASE IS READY TO USE!`.
- Para trocar a senha depois: `docker exec oracle-free /opt/oracle/setPassword.sh <nova_senha>`.

Dados de conexão:

| Item | Valor |
|---|---|
| Host | localhost |
| Porta | 1521 |
| Serviço (PDB) | FREEPDB1 |
| Usuário administrador | system |
| Usuário de estudo | estudo / Estudo#2026 (depois do passo seguinte) |

O CDB raiz (serviço `FREE`) não deve receber objetos de estudo; use sempre o PDB `FREEPDB1`.

### Carregar o schema (usando o SQL*Plus de dentro do container)

```bash
# copia a pasta 00-ambiente para dentro do container
docker cp 00-ambiente oracle-free:/tmp/00-ambiente

# cria o usuário de estudo
docker exec -it oracle-free sqlplus system/'Oracle#2026'@FREEPDB1 @/tmp/00-ambiente/01-criar-usuario.sql

# instala o schema como o usuário de estudo
docker exec -it oracle-free sqlplus estudo/'Estudo#2026'@FREEPDB1 @/tmp/00-ambiente/instalar.sql
```

O resultado final deve ser a tabela de conferência com todas as linhas em `OK`. Cada comando deixa o SQL*Plus aberto no prompt; digite `EXIT` para sair.

## Opção 3 — Instalação local

A Oracle distribui o Free também como instalador para Windows, RPM para Oracle Linux e VM para VirtualBox, na [página de download](https://www.oracle.com/database/free/get-started/). O usuário e o schema são carregados do mesmo jeito da opção 2, com o SQL*Plus ou SQLcl da máquina.

## Clientes

| Cliente | Tipo | Observação |
|---|---|---|
| SQL*Plus | Linha de comando | Vem com o banco e com o Instant Client; referência para os scripts da seção 12 |
| SQLcl | Linha de comando | Gratuito, só precisa de Java; aceita os comandos do SQL*Plus e acrescenta vários (seção 12) |
| SQL Developer | Gráfico | Gratuito; também existe como extensão do VS Code |
| DataGrip / DBeaver | Gráfico | Multibanco; úteis para a seção 14 |

Conexão no formato EZCONNECT, válida para todos: `estudo/Estudo#2026@localhost:1521/FREEPDB1`.

## Acentuação

Os dados de exemplo não têm acento de propósito. Se for inserir texto acentuado pelo SQL*Plus no Windows, configure a variável `NLS_LANG` do cliente com o mesmo conjunto de caracteres do terminal (por exemplo `BRAZILIAN PORTUGUESE_BRAZIL.WE8MSWIN1252` ou `.AL32UTF8`); caso contrário o texto é gravado com caracteres trocados. SQLcl, SQL Developer e DataGrip não têm esse problema.

## Versão

Os ambientes desta página rodam 26ai. Todo o repositório é escrito para funcionar também no 19c; o que depende de versão mais nova está marcado com `[23ai+]` ou `[21c+]`.
