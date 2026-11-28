# Como o Oracle executa uma consulta: parse, otimização, execução

## As etapas

| Etapa | O que acontece |
|---|---|
| **Parse sintático** | O texto é SQL válido? (ORA-00933, ORA-00936...) |
| **Parse semântico** | Tabelas e colunas existem? Há privilégio? (ORA-00942, ORA-00904) |
| **Busca no shared pool** | O mesmo texto, com o mesmo ambiente, já foi otimizado? Se sim, reaproveita o plano |
| **Otimização** | Só se não achou: o otimizador (CBO) gera planos possíveis, estima o custo de cada um com as **estatísticas** e escolhe o mais barato |
| **Geração do row source** | O plano escolhido vira um programa executável |
| **Execução** | Lê os blocos (do cache ou do disco), aplica filtros, junções, ordenação |
| **Fetch** | Devolve as linhas ao cliente, em lotes (`ARRAYSIZE` no SQL*Plus, `fetchSize` no JDBC) |

## Hard parse e soft parse

| | Quando | Custo |
|---|---|---|
| **Hard parse** | Texto nunca visto (ou que saiu do cache, ou cujos objetos mudaram) | Alto: otimização completa, travas no shared pool. Milhares por segundo degradam o banco inteiro |
| **Soft parse** | Texto já está no shared pool | Baixo: só confere permissões e localiza o cursor |
| **Sem parse** | O cursor já está aberto na sessão (PL/SQL mantém cursores em cache; `SESSION_CACHED_CURSORS`) | Mínimo |

O que decide se o texto "já foi visto" é o **texto exato**: espaços, maiúsculas e comentários contam. `WHERE id = 1` e `WHERE id = 2` são duas instruções diferentes; `WHERE id = :id` é uma só, executada com valores diferentes. Por isso bind variable (tópico 07) é a principal regra de desempenho para sistemas com muitas execuções curtas.

SQL estático em PL/SQL já usa bind automaticamente: as variáveis PL/SQL viram binds. O problema aparece em SQL dinâmico montado por concatenação (seção 09, tópico 09) e em aplicações que montam o texto com os valores.

## O otimizador

O otimizador baseado em custo (CBO) não "conhece" os dados: conhece as **estatísticas** (número de linhas, valores distintos, histogramas, tamanho dos índices; tópico 05). Com elas, estima quantas linhas cada etapa vai produzir (**cardinalidade**) e quanto custa cada caminho. Quase todo plano ruim é uma estimativa de cardinalidade errada: o otimizador escolheu bem para o número que imaginou, e o número real era outro. O tópico 03 mostra como comparar o estimado com o real.

## Documentação oficial

- [SQL Tuning Guide — SQL Processing](https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/sql-processing.html)
- [SQL Tuning Guide — Query Optimizer Concepts](https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/query-optimizer-concepts.html)
