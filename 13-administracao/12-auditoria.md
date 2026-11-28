# Auditoria: visão geral

Auditoria registra **quem fez o quê, quando e de onde** no banco, de um jeito que o próprio usuário auditado não consegue apagar. É diferente do log de aplicação e dos triggers de histórico (seção 09, tópicos 04 e 06): é configurada pelo responsável pela segurança, vale para qualquer caminho de acesso (aplicação, SQL Developer, script) e fica protegida.

## Unified Auditing `[12c+]`

O modelo atual. Todos os registros vão para uma trilha única, consultada em `UNIFIED_AUDIT_TRAIL`.

| Conceito | O que é |
|---|---|
| **Política** (`CREATE AUDIT POLICY`) | O que auditar: ações (`UPDATE ON vendas.pedidos`), privilégios usados (`SELECT ANY TABLE`), roles, eventos de login |
| **Ativação** (`AUDIT POLICY`) | Para quem vale: todos, `BY usuario`, `EXCEPT usuario`, só sucesso ou só falha (`WHENEVER [NOT] SUCCESSFUL`) |
| **Condição** (`WHEN ... EVALUATE PER STATEMENT\|SESSION`) | Auditar só quando uma condição vale, por exemplo fora da aplicação |
| Roles | `AUDIT_ADMIN` (cria e ativa políticas, limpa a trilha), `AUDIT_VIEWER` (só consulta) |

```sql
CREATE AUDIT POLICY pol_alteracao_limite
    ACTIONS UPDATE ON vendas.clientes, DELETE ON vendas.clientes
    WHEN 'NVL(SYS_CONTEXT(''USERENV'', ''MODULE''), ''-'') <> ''APP_VENDAS'''
    EVALUATE PER STATEMENT;

AUDIT POLICY pol_alteracao_limite;
```

A política acima registra alteração e exclusão de clientes feitas **fora** da aplicação (por quem entra direto no banco), que é justamente o acesso que mais interessa a uma auditoria. O `NVL` é necessário: numa sessão sem módulo, `NULL <> 'APP_VENDAS'` não é verdadeiro e a ação escaparia. O módulo é informado pelo cliente, então quem conhece a regra pode imitá-lo; para controle forte, combine com o usuário de banco ou o programa de origem.

Políticas que já vêm prontas e, em geral, ativas: `ORA_SECURECONFIG` (comandos administrativos e de segurança) e `ORA_LOGON_FAILURES` (tentativas de login com erro).

## Modo misto e modo puro

No 19c, o padrão é o **modo misto**: as políticas unificadas funcionam, e a auditoria tradicional (parâmetro `AUDIT_TRAIL`, comando `AUDIT SELECT TABLE`, visões `DBA_AUDIT_TRAIL`) também. O **modo puro** (só unificada) exige religar o executável do banco. `V$OPTION`, linha `Unified Auditing`, mostra `TRUE` no modo puro.

A auditoria tradicional está obsoleta e deixou de existir no 23ai: configurações novas devem usar só políticas unificadas.

## Fine-Grained Auditing (FGA)

`DBMS_FGA.ADD_POLICY` audita no nível de **coluna e condição**: "registrar toda consulta que leia a coluna `salario` de funcionários do departamento 30". Registra inclusive `SELECT`, com o texto da instrução e os binds. Os registros também vão para `UNIFIED_AUDIT_TRAIL` no modelo unificado.

## Operar a trilha

| Tarefa | Como |
|---|---|
| Consultar | `UNIFIED_AUDIT_TRAIL` (colunas `EVENT_TIMESTAMP`, `DBUSERNAME`, `OS_USERNAME`, `USERHOST`, `CLIENT_PROGRAM_NAME`, `ACTION_NAME`, `OBJECT_SCHEMA`, `OBJECT_NAME`, `SQL_TEXT`, `RETURN_CODE`, `UNIFIED_AUDIT_POLICIES`) |
| Ver políticas | `AUDIT_UNIFIED_POLICIES` (definição), `AUDIT_UNIFIED_ENABLED_POLICIES` (ativas e para quem) |
| Limpar registros antigos | `DBMS_AUDIT_MGMT.SET_LAST_ARCHIVE_TIMESTAMP` + `CLEAN_AUDIT_TRAIL`, ou um job de limpeza (`CREATE_PURGE_JOB`) |
| Guardar fora do banco | Exportar periodicamente, ou enviar a um SIEM; em ambientes críticos, Oracle Audit Vault |

A trilha cresce sem parar: definir retenção e limpeza é parte de ligar a auditoria. Auditar demais (todo `SELECT` de todas as tabelas) gera volume que ninguém lê e custa desempenho; comece pelo que um incidente de segurança precisaria responder.

## O que vale auditar, de início

- Logins com falha (`ORA_LOGON_FAILURES`).
- Uso de privilégios administrativos e mudanças de usuários, roles e grants (`ORA_SECURECONFIG`).
- DML direto (fora da aplicação) em tabelas sensíveis: financeiro, cadastro, preços, limites de crédito.
- Leitura de colunas de dados pessoais (FGA), quando a legislação de proteção de dados exigir.

## Documentação oficial

- [Database Security Guide — Introduction to Auditing](https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/introduction-to-auditing.html)
- [Database Security Guide — Configuring Audit Policies](https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/configuring-audit-policies.html)
- [SQL Language Reference — CREATE AUDIT POLICY (Unified Auditing)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/CREATE-AUDIT-POLICY-Unified-Auditing.html)
- [PL/SQL Packages and Types Reference — DBMS_FGA](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_FGA.html)
