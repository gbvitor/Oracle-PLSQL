# login.sql e glogin.sql

Dois scripts que o SQL*Plus executa sozinho a cada conexão, para deixar o ambiente do jeito que você gosta (largura da linha, formato de data, prompt com o nome do banco):

| Arquivo | Onde fica | Para quem |
|---|---|---|
| `glogin.sql` (*site profile*) | `$ORACLE_HOME/sqlplus/admin/` (ou a mesma pasta no Instant Client) | Todos os usuários daquela instalação |
| `login.sql` (*user profile*) | Uma pasta indicada por variável de ambiente (abaixo) | Você |

Ordem: primeiro `glogin.sql`, depois `login.sql`. Os dois rodam também a cada `CONNECT` dentro da sessão.

## Onde o SQL*Plus procura o login.sql

A partir do SQL*Plus **12.2**, por segurança, o `login.sql` do **diretório atual não é mais executado** (um `login.sql` malicioso numa pasta compartilhada rodaria sem você perceber). A mudança também chegou a patches do 11.2.0.4. O arquivo precisa estar numa pasta listada em:

| Sistema | Variável |
|---|---|
| Linux / Unix | `ORACLE_PATH` |
| Windows | `SQLPATH` (variável de ambiente ou registro) |

```text
Linux    export ORACLE_PATH=$HOME/sqlplus          (no .bashrc)
Windows  setx SQLPATH "C:\Users\voce\sqlplus"
```

No Linux, `SQLPATH` continua valendo para achar **scripts** chamados com `@`, mas não para o `login.sql`. Quem atualizou o cliente e perdeu as configurações costuma ter caído nessa mudança. No Windows, houve versões do cliente 18 com bug na leitura do `login.sql` via `SQLPATH`; atualize o cliente se o arquivo for ignorado.

A opção de restrição `sqlplus -R 3` impede a execução dos perfis.

## O que costuma ir no login.sql

O arquivo [09-login.sql](09-login.sql) é um modelo comentado. Os itens mais úteis:

- `SET LINESIZE`, `PAGESIZE`, `TRIMSPOOL`, `TAB OFF`: saída legível e arquivos sem lixo.
- `ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY HH24:MI:SS'`: data com hora sempre visível.
- `SET SQLPROMPT "_USER'@'_CONNECT_IDENTIFIER> "`: o prompt mostra **em que banco você está**, a proteção mais simples contra rodar no banco de produção o que era para o de teste.
- `SET SERVEROUTPUT ON SIZE UNLIMITED`.
- `DEFINE _EDITOR = vi` (ou `notepad`) para o comando `EDIT`.

Variáveis predefinidas que o prompt aceita: `_USER`, `_CONNECT_IDENTIFIER`, `_DATE`, `_PRIVILEGE` (mostra `AS SYSDBA`), `_O_VERSION`.

## No SQLcl

O SQLcl também lê `login.sql` (pelas mesmas variáveis e pela pasta do usuário) e aceita os mesmos comandos, além dos próprios, como `SET SQLFORMAT ansiconsole` e `SET STATUSBAR ON` (tópico 10).

## Documentação oficial

- [SQL*Plus User's Guide — Configuring SQL*Plus: Site Profile e User Profile](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/configuring-SQL-Plus.html)
- [SQL*Plus User's Guide — SET SQLPROMPT](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/SET-system-variable-summary.html)
