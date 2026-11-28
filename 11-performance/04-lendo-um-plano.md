# Lendo um plano: ordem, métodos de acesso, junções e cardinalidade

## Em que ordem ler

O plano é uma árvore desenhada com recuo. Regras:

1. Uma operação com filhos só produz linhas a partir do que os filhos entregam.
2. Entre irmãos (mesmo recuo, mesmo pai), o **primeiro** (de cima) roda primeiro.
3. Na prática: comece pela operação **mais recuada e mais acima**, suba para o pai, depois desça para o próximo filho dele.

```
0 SELECT STATEMENT
1   HASH JOIN
2     TABLE ACCESS FULL  CLIENTES     <- 1º: lê clientes e monta a tabela hash
3     TABLE ACCESS FULL  PEDIDOS      <- 2º: lê pedidos e procura cada um na hash
```

O `Id` é só um número de referência para a seção de predicados; não é a ordem de execução.

## Métodos de acesso

| Operação | Quando aparece | Leitura |
|---|---|---|
| `TABLE ACCESS FULL` | Muitas linhas, ou nenhum índice útil | Lê todos os blocos da tabela, com leituras grandes (multiblock). Não é ruim por si: para 30% da tabela, costuma ser o mais rápido |
| `INDEX UNIQUE SCAN` | Igualdade em todas as colunas de um índice único | No máximo uma entrada |
| `INDEX RANGE SCAN` | Igualdade em parte das colunas, faixa (`BETWEEN`, `>`), `LIKE 'abc%'` | Uma faixa do índice, em ordem |
| `TABLE ACCESS BY INDEX ROWID [BATCHED]` | Depois de um acesso por índice, para buscar as colunas que não estão nele | Um bloco da tabela por linha (BATCHED agrupa pedidos ao mesmo bloco) |
| `INDEX FULL SCAN` | O índice inteiro, em ordem, para evitar um SORT | Bloco a bloco |
| `INDEX FAST FULL SCAN` | Todas as colunas necessárias estão no índice; a ordem não importa | O índice lido como se fosse uma tabela menor, multibloco |
| `INDEX SKIP SCAN` | Índice composto, filtro só na segunda coluna, e a primeira tem poucos valores | Uma busca por valor da primeira coluna |

Um índice que já contém todas as colunas pedidas evita o acesso à tabela (*covering index*): o plano não tem `TABLE ACCESS BY INDEX ROWID`.

## Métodos de junção

| Junção | Como funciona | Bom quando |
|---|---|---|
| `NESTED LOOPS` | Para cada linha da tabela externa (a primeira), busca as correspondentes na interna, normalmente por índice | Poucas linhas na externa e índice na coluna de junção da interna. Responde rápido as primeiras linhas |
| `HASH JOIN` | Lê a tabela menor e monta uma tabela hash em memória; depois lê a maior e procura cada linha na hash | Muitas linhas dos dois lados, junção por igualdade. O método típico de relatórios |
| `MERGE JOIN` (sort merge) | Ordena os dois lados pela chave e percorre juntos | Dados já ordenados (por índice), ou junção por desigualdade (`<`, `BETWEEN`) |

No nested loops, a operação interna aparece com `Starts` igual ao número de linhas da externa (tópico 03). Nested loops com milhões de linhas na externa, escolhido porque o otimizador estimou poucas, é um dos planos ruins mais comuns.

`[12c+]` **Planos adaptativos** podem trocar nested loops por hash join durante a execução, quando as linhas reais passam de um limite. Aparecem com a nota `this is an adaptive plan` e com o formato `+ADAPTIVE`.

## Custo e cardinalidade

- **`Rows`** (cardinalidade estimada): o número mais importante do plano. Erro grande aqui leva a escolha errada de acesso e de junção.
- **`Cost`**: número interno, comparável só entre planos **da mesma instrução**. Custo menor não garante tempo menor quando a estimativa de linhas está errada. Não compare custo de consultas diferentes.
- **`Time`**: derivado do custo; tem a mesma limitação.

## Documentação oficial

- [SQL Tuning Guide — Reading Execution Plans](https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/reading-execution-plans.html)
- [SQL Tuning Guide — Optimizer Access Paths](https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/optimizer-access-paths.html)
- [SQL Tuning Guide — Joins](https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/joins.html)
