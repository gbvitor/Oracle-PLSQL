# Bind variables, bind peeking e adaptive cursor sharing

## Por que bind

Com bind, a mesma instrução é reaproveitada para qualquer valor: um hard parse, milhares de execuções (tópico 01). Sem bind, cada valor é um texto novo. Num sistema com muitas execuções curtas (OLTP), a falta de bind satura o shared pool e a CPU de parse; é o problema de escalabilidade mais comum em aplicações Oracle. Além disso, bind evita SQL injection (seção 09, tópico 09).

## O problema do plano único

Um texto com bind tem, a princípio, **um plano** para todos os valores. Se a coluna tem distribuição torta, o melhor plano depende do valor: para `status = 'CANCELADO'` (200 linhas), índice; para `status = 'ENTREGUE'` (197.800), leitura completa.

## Bind peeking `[9i+]`

No hard parse, o otimizador **espia** o valor do bind daquela primeira execução e otimiza para ele, usando o histograma. As execuções seguintes reaproveitam o plano, qualquer que seja o valor. Se a primeira execução depois de o cursor entrar no shared pool for com um valor atípico, todos herdam o plano dele: a origem dos "às vezes a mesma tela fica lenta, e no dia seguinte volta ao normal".

## Adaptive cursor sharing `[11g+]`

O Oracle percebe o problema e corrige, em etapas:

1. Cursor com bind numa coluna com histograma é marcado **bind sensitive** (`V$SQL.IS_BIND_SENSITIVE = 'Y'`).
2. Quando uma execução processa um volume muito diferente do esperado, o cursor vira **bind aware** (`IS_BIND_AWARE = 'Y'`).
3. Daí em diante, o Oracle verifica a seletividade do valor a cada execução e cria **cursores filhos** com planos diferentes por faixa de seletividade (`V$SQL.CHILD_NUMBER` 0, 1, 2...).

A correção não é imediata: a execução "ruim" que dispara a mudança já aconteceu. Ferramentas para garantir o plano quando isso não basta: SQL Plan Baselines (estabilidade de plano, sem custo extra de licença na Enterprise Edition), o hint `BIND_AWARE`, ou literal para a coluna torta quando ela tem poucos valores e a instrução roda pouco.

## Ver o valor espiado

`DBMS_XPLAN.DISPLAY_CURSOR(sql_id, child, 'TYPICAL +PEEKED_BINDS')` mostra os valores usados no parse de cada filho. `V$SQL_BIND_CAPTURE` amostra valores de binds em execução.

## Onde o bind vem

| Origem | Bind? |
|---|---|
| SQL estático em PL/SQL (`WHERE id = v_id`) | Sim, automático |
| `EXECUTE IMMEDIATE ... USING` | Sim |
| `EXECUTE IMMEDIATE 'WHERE id = ' \|\| v_id` | Não |
| Java `PreparedStatement` com `?` / Python com `:1` | Sim |
| Texto montado na aplicação com o valor | Não |
| SQL*Plus `VARIABLE x` + `:x` | Sim |

`CURSOR_SHARING = FORCE` troca literais por binds no banco inteiro como paliativo para aplicação que não usa bind. Resolve o parse, mas aplica o problema do plano único a todas as instruções; use como medida temporária.

## Documentação oficial

- [SQL Tuning Guide — Adaptive Cursor Sharing](https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/improving-rwp-cursor-sharing.html)
- [Database Reference — V$SQL (IS_BIND_SENSITIVE, IS_BIND_AWARE)](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/V-SQL.html)
