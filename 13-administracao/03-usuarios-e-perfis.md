# Usuários, perfis e senhas

## Usuário e schema

No Oracle, **usuário e schema são a mesma coisa**: criar o usuário `VENDAS` cria o schema `VENDAS`, onde ficam os objetos dele. O usuário de estudo do repositório (`00-ambiente/01-criar-usuario.sql`) é o exemplo completo.

```sql
CREATE USER vendas IDENTIFIED BY "Senha#Forte2026"
    DEFAULT TABLESPACE users
    TEMPORARY TABLESPACE temp
    QUOTA 500M ON users
    PROFILE perfil_aplicacao
    PASSWORD EXPIRE;
```

| Cláusula | Efeito |
|---|---|
| `DEFAULT TABLESPACE` | Onde vão as tabelas criadas sem `TABLESPACE` explícito |
| `QUOTA n ON ts` / `UNLIMITED` | Espaço que pode ocupar (sem cota: ORA-01950 ao criar a primeira tabela com dados) |
| `PROFILE` | Regras de senha e de recursos |
| `PASSWORD EXPIRE` | Obriga a trocar a senha no primeiro login |
| `ACCOUNT LOCK` | Cria bloqueado |

Manutenção comum:

```sql
ALTER USER vendas IDENTIFIED BY "NovaSenha#2026";
ALTER USER vendas ACCOUNT UNLOCK;
ALTER USER vendas QUOTA UNLIMITED ON users;
DROP USER vendas CASCADE;
```

`DROP USER ... CASCADE` apaga o schema inteiro, com todos os objetos e dados. Sem `CASCADE`, falha se houver objetos.

## Schema sem login `[18c+]`

```sql
CREATE USER app_dados NO AUTHENTICATION;
```

Um schema que **não aceita conexão**: guarda as tabelas da aplicação, e a aplicação conecta com outro usuário que recebe só os privilégios necessários (ou por proxy). É o desenho recomendado para separar o dono dos objetos de quem os usa.

## Perfis

Um perfil agrupa limites de senha e de recurso. Todo usuário tem um (`DEFAULT` se nenhum for indicado).

| Parâmetro | Faz |
|---|---|
| `FAILED_LOGIN_ATTEMPTS n` | Bloqueia a conta depois de n tentativas erradas |
| `PASSWORD_LOCK_TIME dias` | Por quanto tempo fica bloqueada (fração de dia aceita: `1/24` = 1 hora) |
| `PASSWORD_LIFE_TIME dias` | Validade da senha |
| `PASSWORD_GRACE_TIME dias` | Prazo para trocar depois de vencida |
| `PASSWORD_REUSE_TIME` / `PASSWORD_REUSE_MAX` | Quando uma senha antiga pode voltar |
| `PASSWORD_VERIFY_FUNCTION` | Função que valida a complexidade (`ORA12C_VERIFY_FUNCTION` vem pronta) |
| `INACTIVE_ACCOUNT_TIME dias` `[12.2+]` | Bloqueia contas sem login há n dias |
| `SESSIONS_PER_USER`, `IDLE_TIME`, `CONNECT_TIME`, `CPU_PER_CALL` | Limites de recurso; só valem com o parâmetro `RESOURCE_LIMIT = TRUE` (padrão desde o 12c) |

O perfil `DEFAULT` costuma ter `PASSWORD_LIFE_TIME 180`: contas de aplicação vencem em 6 meses e a aplicação para de conectar. Para contas técnicas, crie um perfil próprio, com senha sem vencimento e controle de troca feito de outra forma (cofre de senhas), em vez de alterar o `DEFAULT`.

## Situação da conta

`DBA_USERS.ACCOUNT_STATUS`:

| Valor | Significa |
|---|---|
| `OPEN` | Normal |
| `EXPIRED` | Senha vencida: precisa trocar no próximo login |
| `EXPIRED(GRACE)` | Vencendo: avisada a cada login |
| `LOCKED` | Bloqueada pelo DBA |
| `LOCKED(TIMED)` | Bloqueada por tentativas erradas; libera sozinha depois do `PASSWORD_LOCK_TIME` |

Uma aplicação com senha errada configurada num pool de conexões bloqueia a conta em segundos, para todos os usuários da aplicação. Quando "o sistema parou de conectar de repente", `LOCKED(TIMED)` é a primeira suspeita.

## Documentação oficial

- [SQL Language Reference — CREATE USER](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/CREATE-USER.html)
- [SQL Language Reference — CREATE PROFILE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/CREATE-PROFILE.html)
- [Database Security Guide — Managing Security for Oracle Database Users](https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/managing-security-for-oracle-database-users.html)
