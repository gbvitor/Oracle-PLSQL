# Tabelas temporárias

## Global temporary table (GTT)

A **estrutura** é permanente e compartilhada; os **dados** são privados de cada sessão e duram só até o fim da transação ou da sessão.

```sql
-- ON COMMIT DELETE ROWS (padrão): dados somem no COMMIT
-- ON COMMIT PRESERVE ROWS: dados ficam até o fim da sessão
CREATE GLOBAL TEMPORARY TABLE gtt_calculo (
    id_produto NUMBER,
    valor      NUMBER
) ON COMMIT DELETE ROWS;
```

- Duas sessões usando a mesma GTT ao mesmo tempo nunca veem os dados uma da outra.
- A tabela é criada **uma vez** (é DDL e faz commit), como parte da instalação; não se cria GTT dentro de procedure a cada execução.
- Os dados ficam no tablespace temporário e geram muito menos redo que uma tabela comum. Desde o 12c, com `TEMP_UNDO_ENABLED`, o undo também vai para o temporário.
- Desde o 12c, as estatísticas podem ser **por sessão** (padrão), o que evita que o plano de uma sessão com 10 linhas seja usado por outra com 10 milhões.
- Índices e constraints podem ser criados; também são temporários por sessão.

Uso: área de trabalho de um processamento em várias etapas (carregar uma lista de ids, calcular, juntar com outras tabelas), resultado intermediário de relatório, lista de parâmetros vinda da aplicação.

## Private temporary table `[18c+]`

A **estrutura também é temporária**: criada na sessão, invisível para as outras, apagada no fim da transação ou da sessão.

```sql
-- ON COMMIT DROP DEFINITION (padrão): some no COMMIT
-- ON COMMIT PRESERVE DEFINITION: dura até o fim da sessão
CREATE PRIVATE TEMPORARY TABLE ora$ptt_calculo (
    id_produto NUMBER,
    valor      NUMBER
) ON COMMIT DROP DEFINITION;
```

- O nome precisa começar com o prefixo do parâmetro `PRIVATE_TEMP_TABLE_PREFIX`, por padrão `ORA$PTT_`.
- **Não** faz commit ao ser criada (diferente de todo outro DDL).
- Não aceita índices nem materialized views, e tem outras restrições listadas na documentação (colunas com valor padrão, entre elas). Também não pode ser citada em código PL/SQL armazenado compilado estaticamente, porque não existe na compilação: só por SQL dinâmico.
- Útil em scripts e consultas ad hoc; para processamento recorrente em procedures, a GTT continua sendo a escolha.

## Comparação

| | GTT | Private temporary table |
|---|---|---|
| Estrutura | Permanente, compartilhada | Temporária, só da sessão |
| Dados | Privados da sessão | Privados da sessão |
| Criação faz commit | Sim | Não |
| Índices | Sim | Não |
| Uso em PL/SQL estático | Sim | Não |
| Disponível | Desde o 8i | Desde o 18c |

## Documentação oficial

- [Administrator's Guide — Creating a Temporary Table](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/managing-tables.html)
- [SQL Language Reference — CREATE TABLE (GLOBAL TEMPORARY, PRIVATE TEMPORARY)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/CREATE-TABLE.html)
