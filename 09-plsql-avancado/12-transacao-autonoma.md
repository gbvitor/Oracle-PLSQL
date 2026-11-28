# PRAGMA AUTONOMOUS_TRANSACTION

Uma rotina autônoma roda numa **transação independente** da de quem a chamou. O que ela grava e confirma fica gravado mesmo que o chamador desfaça tudo depois; o que o chamador ainda não confirmou, ela não enxerga.

```sql
CREATE OR REPLACE PROCEDURE registrar_erro (
    p_rotina IN VARCHAR2, p_codigo IN NUMBER, p_mensagem IN VARCHAR2
) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO log_erro (rotina, codigo, mensagem) VALUES (p_rotina, p_codigo, p_mensagem);
    COMMIT;
END;
/
```

## Onde pode ser usado

- Procedure e function (armazenadas ou locais).
- Rotina de package (cada rotina, não a package inteira).
- Trigger.
- Bloco anônimo de nível mais alto (não em bloco aninhado).

## Regras

| Regra | Consequência |
|---|---|
| Precisa terminar com `COMMIT` ou `ROLLBACK` | Se sair com transação pendente: ORA-06519, e o que ela fez é desfeito |
| Não enxerga o que o chamador não confirmou | Consulta dentro dela vê o banco como as outras sessões veem |
| O chamador fica suspenso enquanto ela roda | Se ela tentar travar uma linha que o chamador travou, espera por si mesma: **deadlock** (ORA-00060) |
| COMMIT dela não confirma nada do chamador | São transações separadas |

## Usos legítimos

- **Log de erro e de execução**: o registro precisa sobreviver ao ROLLBACK de quem falhou. É o caso que a seção 08 (tópico 10) deixou em aberto.
- **Auditoria** gravada por trigger, que precisa ficar mesmo se a operação auditada for desfeita.
- **Contador ou numerador próprio** que não pode voltar atrás (quando sequence não serve).

## Abuso comum

Transação autônoma também "resolve" ORA-14551 (DML em function chamada por SELECT) e ORA-04091 (tabela mutante), porque roda fora da instrução em curso. É quase sempre um erro de projeto:

- No trigger de tabela mutante, a rotina autônoma não enxerga as linhas que a instrução está alterando: calcula sobre dados velhos.
- Se a instrução principal falhar e for desfeita, o que a rotina autônoma gravou continua lá: dado inconsistente.

Use compound trigger (tópico 05) ou repense a regra.

## Documentação oficial

- [PL/SQL Language Reference — AUTONOMOUS_TRANSACTION Pragma](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/AUTONOMOUS_TRANSACTION-pragma.html)
- [PL/SQL Language Reference — Autonomous Transactions](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/static-sql.html)
