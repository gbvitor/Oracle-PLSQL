# Triggers INSTEAD OF e triggers de sistema (DDL, LOGON)

## INSTEAD OF: DML em view que não é atualizável

View com `GROUP BY`, `DISTINCT`, funções de agregação, operadores de conjunto ou joins sem tabela key-preserved não aceita `INSERT`/`UPDATE`/`DELETE` (ORA-01732, ORA-01779; seção 07, tópico 05). Um trigger `INSTEAD OF` diz ao Oracle o que fazer **no lugar** do DML:

```sql
CREATE OR REPLACE TRIGGER trg_vw_pedidos_resumo_iod
    INSTEAD OF DELETE ON vw_pedidos_resumo
    FOR EACH ROW
BEGIN
    UPDATE pedidos SET status = 'CANCELADO' WHERE id_pedido = :OLD.id_pedido;
END;
/
```

- Só existe em view, e sempre é de linha (`FOR EACH ROW` é implícito; escrever é opcional).
- Não tem `BEFORE`/`AFTER`, nem `WHEN`, nem `UPDATE OF coluna`. Para saber qual coluna o usuário tentou mudar, compare `:NEW` com `:OLD` (com `NVL` ou `DECODE` se a coluna aceitar NULL).
- Uso típico: dar a uma aplicação uma "tabela" que na verdade é um join ou um resumo, com as regras de gravação centralizadas no trigger. O exemplo do script transforma o `DELETE` na view em cancelamento lógico do pedido.

## Triggers de sistema

Disparam por eventos do banco, não de uma tabela.

| Evento | Exemplos de uso |
|---|---|
| `BEFORE`/`AFTER` `CREATE`, `ALTER`, `DROP`, `TRUNCATE`, `GRANT`, `DDL` (todos) | Auditar mudança de estrutura; impedir DROP de objetos críticos |
| `AFTER LOGON`, `BEFORE LOGOFF` | Configurar a sessão (formato de data, identificador); registrar acesso |
| `AFTER SERVERERROR` | Registrar erros de qualquer sessão |
| `AFTER STARTUP`, `BEFORE SHUTDOWN` | Rotinas de instância (só nível `DATABASE`) |

Dois escopos:

- `ON SCHEMA`: eventos do próprio schema. Basta `CREATE TRIGGER`.
- `ON DATABASE`: eventos de todos os usuários. Exige o privilégio `ADMINISTER DATABASE TRIGGER`, normalmente só do DBA.

Funções de atributo de evento, disponíveis dentro do trigger:

| Função | Devolve |
|---|---|
| `ORA_SYSEVENT` | O evento (`CREATE`, `DROP`, `LOGON`...) |
| `ORA_DICT_OBJ_TYPE` | Tipo do objeto afetado (`TABLE`, `INDEX`...) |
| `ORA_DICT_OBJ_NAME` | Nome do objeto |
| `ORA_DICT_OBJ_OWNER` | Dono do objeto |
| `ORA_LOGIN_USER` | Usuário da sessão |
| `ORA_SQL_TXT(lista)` | Texto da instrução DDL, em partes |

## Cuidados

- **Trigger de LOGON com erro impede o login.** Se o corpo falhar, a conexão é recusada para os usuários afetados (o DBA, com `ADMINISTER DATABASE TRIGGER`, ainda entra e pode desabilitar). Teste o corpo num bloco anônimo antes de transformá-lo em trigger, e mantenha-o mínimo.
- Trigger de DDL dispara também para os scripts de manutenção e para as ferramentas de deploy. Um `BEFORE DROP` que bloqueia demais trava o próprio time.
- O log gravado por trigger de DDL usa `PRAGMA AUTONOMOUS_TRANSACTION` (tópico 12) para ficar independente da transação de quem executou.
- Para auditoria formal (quem fez o quê, com retenção e proteção contra adulteração), o recurso próprio é o **Unified Auditing** (seção 13), não triggers.

## Documentação oficial

- [PL/SQL Language Reference — INSTEAD OF DML Triggers](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-triggers.html)
- [PL/SQL Language Reference — System Triggers](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-triggers.html)
- [PL/SQL Language Reference — Event Attribute Functions](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-triggers.html)
