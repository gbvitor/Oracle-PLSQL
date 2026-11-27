# Triggers DML: linha e instrução, BEFORE e AFTER, :NEW e :OLD

Trigger é um bloco PL/SQL que o Oracle executa sozinho quando acontece um evento numa tabela (ou view, ou no banco). Este tópico trata dos triggers de DML; os de view e de sistema estão no tópico 06.

```sql
CREATE OR REPLACE TRIGGER trg_produtos_hist_preco
    BEFORE UPDATE OF preco_unitario ON produtos
    FOR EACH ROW
    WHEN (NEW.preco_unitario <> OLD.preco_unitario)
BEGIN
    INSERT INTO hist_preco (id_produto, preco_antigo, preco_novo)
    VALUES (:OLD.id_produto, :OLD.preco_unitario, :NEW.preco_unitario);
END;
/
```

## Tipos e momento

| | Nível de instrução (padrão) | Nível de linha (`FOR EACH ROW`) |
|---|---|---|
| Executa | Uma vez por instrução, **mesmo que nenhuma linha seja afetada** | Uma vez por linha afetada |
| `:NEW` / `:OLD` | Não existem | Existem |
| Uso típico | Regra sobre a operação (horário permitido, log de "quem rodou") | Regra sobre cada linha (validação, valor padrão, histórico) |

Ordem numa instrução que afeta duas linhas:

```
BEFORE STATEMENT
  BEFORE ROW  (linha 1)
  AFTER ROW   (linha 1)
  BEFORE ROW  (linha 2)
  AFTER ROW   (linha 2)
AFTER STATEMENT
```

Triggers do mesmo tipo e momento na mesma tabela não têm ordem garantida, a não ser com `FOLLOWS` / `PRECEDES` `[11g+]`. Melhor ainda: um trigger por momento, chamando procedures.

## :NEW e :OLD

| Evento | `:OLD` | `:NEW` |
|---|---|---|
| INSERT | Tudo NULL | Valores inseridos |
| UPDATE | Valores antes | Valores depois (alteráveis em BEFORE) |
| DELETE | Valores excluídos | Tudo NULL |

- Só um trigger **BEFORE ROW** pode alterar `:NEW` (normalizar texto, preencher padrão, calcular coluna). Em AFTER, ORA-04084.
- Na cláusula `WHEN`, os nomes vão **sem dois-pontos**: `WHEN (NEW.status = 'CANCELADO')`. O `WHEN` evita executar o corpo para linhas que não interessam.
- `UPDATE OF coluna` limita o disparo a instruções que **citam** a coluna no `SET`, mesmo que o valor não mude. Para "só quando mudou", compare `:NEW` e `:OLD` (com cuidado com NULL).

## Predicados de evento

Num trigger de vários eventos (`BEFORE INSERT OR UPDATE OR DELETE`):

```sql
IF INSERTING THEN ...
ELSIF UPDATING('preco_unitario') THEN ...
ELSIF DELETING THEN ...
END IF;
```

## Regras e cuidados

- **Sem COMMIT ou ROLLBACK** no trigger (ORA-04092). O trigger faz parte da transação de quem disparou; se o trigger falhar, a instrução inteira é desfeita.
- Erro levantado no trigger (`RAISE_APPLICATION_ERROR`) cancela a instrução: é a forma de implementar regra que constraint não expressa.
- Trigger de linha que consulta a própria tabela dá **tabela mutante** (ORA-04091, tópico 05).
- Lógica escondida: quem lê o `INSERT` não vê o que o trigger faz. Prefira constraint (`CHECK`, `NOT NULL`, `DEFAULT`, FK) e coluna `IDENTITY` quando resolvem; trigger para o resto.
- Custo: trigger de linha numa carga de milhões de linhas executa milhões de vezes. Carga direta (`INSERT /*+ APPEND */`) é convertida em convencional quando a tabela tem trigger.
- Trigger **desabilitado** não dispara: `ALTER TRIGGER nome DISABLE`, `ALTER TABLE t DISABLE ALL TRIGGERS`. Útil em carga de massa controlada; perigoso se esquecido.

## Documentação oficial

- [PL/SQL Language Reference — PL/SQL Triggers](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-triggers.html)
- [PL/SQL Language Reference — CREATE TRIGGER Statement](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/CREATE-TRIGGER-statement.html)
