# Pseudocolunas

## O que é

Uma pseudocoluna se comporta como coluna numa consulta, mas não está gravada na tabela: o Oracle calcula o valor na hora. Dá para selecioná-la e filtrar por ela, mas não para inserir, alterar ou apagar.

## ROWNUM

Número sequencial (1, 2, 3...) atribuído a cada linha **no momento em que ela passa pelo WHERE**, antes de qualquer `ORDER BY`.

Daí vêm os dois erros clássicos:

```sql
-- Errado: pega 3 linhas quaisquer e depois ordena essas 3.
SELECT nome, salario FROM funcionarios WHERE ROWNUM <= 3 ORDER BY salario DESC;

-- Errado: nunca devolve nada. A primeira linha recebe ROWNUM 1, é rejeitada,
-- a próxima também recebe 1, e assim por diante.
SELECT nome FROM funcionarios WHERE ROWNUM = 2;
```

Para "os 3 maiores salários", a ordenação precisa acontecer antes, numa subquery, ou com `FETCH FIRST` (seção 02):

```sql
SELECT nome, salario
  FROM (SELECT nome, salario FROM funcionarios ORDER BY salario DESC)
 WHERE ROWNUM <= 3;

SELECT nome, salario FROM funcionarios ORDER BY salario DESC FETCH FIRST 3 ROWS ONLY;
```

Em código novo, prefira `FETCH FIRST` ou `ROW_NUMBER()`. `ROWNUM` continua comum em código existente e como forma rápida de limitar amostra: `WHERE ROWNUM <= 10`.

## ROWID

Endereço físico da linha: objeto, arquivo, bloco e posição dentro do bloco. É o caminho mais rápido para chegar a uma linha, e é o que os índices guardam.

- Serve para localizar uma linha dentro da mesma transação, por exemplo, para apagar duplicidades (seção 05).
- **Não é identificador permanente.** Muda quando a tabela é movida, reorganizada, exportada e importada, ou quando a linha muda de partição. Nunca grave ROWID como chave.

## LEVEL

Profundidade da linha numa consulta hierárquica com `CONNECT BY`: 1 para a raiz, 2 para os filhos, e assim por diante. Detalhado na seção 02. Uso frequente fora de hierarquias, para gerar uma sequência de números:

```sql
-- 1 a 12
SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 12;
```

Outras pseudocolunas hierárquicas: `CONNECT_BY_ISLEAF`, `CONNECT_BY_ISCYCLE`.

## Sequences: NEXTVAL e CURRVAL

`minha_seq.NEXTVAL` gera o próximo valor; `minha_seq.CURRVAL` devolve o último valor gerado **na sessão atual** (dá erro se a sessão ainda não chamou `NEXTVAL`). Seção 07.

## Outras

| Pseudocoluna | O que devolve |
|---|---|
| `ORA_ROWSCN` | Número de mudança do sistema (SCN) da última alteração confirmada do bloco (ou da linha, se a tabela tiver `ROWDEPENDENCIES`) |
| `COLUMN_VALUE` | Valor de cada elemento quando se consulta uma coleção com `TABLE()` |
| `OBJECT_VALUE` / `OBJECT_ID` | Usadas em tabelas de objetos e XMLType |
| `VERSIONS_*` | Usadas em Flashback Version Query (seção 13) |

## Funções que parecem pseudocolunas

`SYSDATE`, `SYSTIMESTAMP`, `CURRENT_DATE`, `USER` e `UID` são **funções sem argumento**, não pseudocolunas: devolvem o mesmo valor para todas as linhas de uma consulta.

- `SYSDATE` / `SYSTIMESTAMP`: data e hora do sistema operacional do servidor do banco.
- `CURRENT_DATE` / `CURRENT_TIMESTAMP`: data e hora no fuso horário da sessão.

Com servidor e usuários em fusos diferentes, os dois pares dão horários diferentes.

## Documentação oficial

- [SQL Language Reference — Pseudocolumns](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Pseudocolumns.html)
