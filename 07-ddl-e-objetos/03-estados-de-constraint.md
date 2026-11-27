# Estados de constraint: DISABLE, NOVALIDATE, DEFERRABLE

## Habilitada e validada

Toda constraint tem dois atributos independentes:

| Atributo | Significa |
|---|---|
| `ENABLE` / `DISABLE` | Verifica (ou não) os dados **novos** e alterados |
| `VALIDATE` / `NOVALIDATE` | Garante (ou não) que os dados **existentes** obedecem |

| Combinação | Uso |
|---|---|
| `ENABLE VALIDATE` (padrão) | Tudo garantido |
| `ENABLE NOVALIDATE` | Daqui para frente, sim; o passado não é conferido. Útil para ligar uma regra numa tabela com dados antigos ruins, sem ter de corrigir tudo antes |
| `DISABLE NOVALIDATE` | Constraint desligada. Usado em carga massiva, para religar depois |
| `DISABLE VALIDATE` | Desligada para DML, mas declara que os dados obedecem; a tabela fica bloqueada para alteração |

```sql
ALTER TABLE t DISABLE CONSTRAINT ck_t_valor;
ALTER TABLE t ENABLE NOVALIDATE CONSTRAINT ck_t_valor;
-- equivale a ENABLE VALIDATE
ALTER TABLE t ENABLE CONSTRAINT ck_t_valor;
```

## Encontrar as linhas que impedem a validação

Ao tentar `ENABLE VALIDATE` com dados inválidos, o comando falha. Para saber quais linhas são o problema:

```sql
-- Tabela de exceções (uma vez): script do Oracle ou criação manual
CREATE TABLE exceptions (row_id ROWID, owner VARCHAR2(128), table_name VARCHAR2(128), constraint VARCHAR2(128));

ALTER TABLE t ENABLE VALIDATE CONSTRAINT ck_t_valor EXCEPTIONS INTO exceptions;
-- falha, mas grava em EXCEPTIONS o ROWID de cada linha inválida
```

Na prática, uma consulta com a condição negada (`WHERE NOT (valor >= 0)`) costuma ser mais direta.

## DEFERRABLE

Por padrão, a constraint é verificada **ao fim de cada comando** (`IMMEDIATE`). Uma constraint criada como `DEFERRABLE` pode ter a verificação adiada para o **COMMIT**:

```sql
CONSTRAINT fk_x FOREIGN KEY (...) REFERENCES ... DEFERRABLE INITIALLY IMMEDIATE

-- só nesta transação
SET CONSTRAINT fk_x DEFERRED;
SET CONSTRAINTS ALL DEFERRED;
```

Útil quando uma sequência de comandos passa por estados intermediários inválidos que se resolvem antes do fim: trocar duas chaves de lugar, inserir filho antes do pai numa carga, dependências circulares.

Se no `COMMIT` a constraint continuar violada, o commit **falha e toda a transação é desfeita** (ORA-02091 com a causa em seguida).

Cuidados:

- `DEFERRABLE` só pode ser definido na criação da constraint; não dá para alterar uma existente (é preciso recriar).
- PK e UK `DEFERRABLE` usam índice **não único** (porque duplicidades temporárias são permitidas), o que pode mudar planos de execução.
- O otimizador confia menos em constraints adiáveis e em `NOVALIDATE` para transformar consultas.

## Documentação oficial

- [SQL Language Reference — constraint (Constraint States)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/constraint.html)
- [SQL Language Reference — SET CONSTRAINT](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SET-CONSTRAINT.html)
