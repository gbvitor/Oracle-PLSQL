# Ordem lógica de execução do SELECT

## A ordem

Um `SELECT` é escrito numa ordem e avaliado em outra. A ordem lógica, que define o que cada cláusula pode enxergar, é:

| Passo | Cláusula | O que acontece |
|---|---|---|
| 1 | `FROM` / `JOIN` | Monta o conjunto de linhas de origem |
| 2 | `WHERE` | Filtra linhas (e atribui `ROWNUM`) |
| 3 | `GROUP BY` | Agrupa as linhas |
| 4 | `HAVING` | Filtra grupos |
| 5 | `SELECT` | Calcula as expressões e as funções analíticas; define os aliases |
| 6 | `DISTINCT` | Elimina linhas repetidas |
| 7 | `ORDER BY` | Ordena |
| 8 | `OFFSET` / `FETCH` | Corta o resultado |

`UNION`, `INTERSECT` e `MINUS` combinam os resultados de cada `SELECT` depois do passo 6; o `ORDER BY` final vale para o resultado combinado.

Em consulta hierárquica (`START WITH` / `CONNECT BY`), o Oracle avalia primeiro os joins, depois monta a árvore e só então aplica as demais condições do `WHERE`. Consequência: o `WHERE` tira linhas do resultado, mas não poda a árvore; um funcionário filtrado no `WHERE` some da listagem, e os subordinados dele continuam aparecendo. Para podar um ramo, a condição vai no `CONNECT BY`. Detalhes na seção 02.

O otimizador pode executar fisicamente em outra ordem (aplicar um filtro antes de um join, por exemplo), mas o **resultado** sempre é o que a ordem lógica determina.

## Consequências

**Alias de coluna não existe no WHERE.** O alias é criado no passo 5; o `WHERE` roda no 2.

```sql
-- ORA-00904: "ANUAL": identificador inválido
SELECT nome, salario * 12 AS anual FROM funcionarios WHERE anual > 100000;

-- Correto: repetir a expressão
SELECT nome, salario * 12 AS anual FROM funcionarios WHERE salario * 12 > 100000;
```

**Alias de coluna existe no ORDER BY**, que roda depois do `SELECT`: `ORDER BY anual` funciona.

**Agregação não vai no WHERE.** No passo 2 ainda não existem grupos. Filtro sobre `SUM`, `COUNT`, `AVG` vai no `HAVING` (ORA-00934 se estiver no `WHERE`).

**Função analítica não vai no WHERE nem no HAVING.** `ROW_NUMBER()`, `RANK()`, `SUM() OVER` são calculadas no passo 5. Para filtrar por elas, a consulta precisa de um nível a mais (ORA-30483):

```sql
SELECT *
  FROM (SELECT nome, salario,
               RANK() OVER (ORDER BY salario DESC) AS posicao
          FROM funcionarios)
 WHERE posicao <= 3;
```

**Função analítica enxerga o resultado depois do WHERE e do GROUP BY.** `COUNT(*) OVER ()` conta as linhas que sobraram, não as da tabela.

**ROWNUM é atribuído no WHERE**, antes do `ORDER BY` (tópico 06).

**Alias no GROUP BY** não é aceito no 19c, porque o `GROUP BY` roda antes do `SELECT`: repita a expressão. `[23ai+]` O 23ai passou a aceitar alias de coluna no `GROUP BY` e no `HAVING`, e posição da coluna no `GROUP BY` quando o parâmetro `group_by_position_enabled` está ligado.

**DISTINCT com ORDER BY por coluna fora do SELECT** dá ORA-01791: depois do `DISTINCT`, só sobram as colunas selecionadas.

## Ler uma consulta complexa

Na ordem lógica: primeiro o `FROM` (de onde vêm os dados e como se juntam), depois o `WHERE` (o que fica de fora), depois o agrupamento, e só então o `SELECT`. Começar a leitura pelo `SELECT` é o que costuma levar a conclusões erradas sobre o que a consulta devolve.

## Documentação oficial

- [SQL Language Reference — SELECT](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SELECT.html)
