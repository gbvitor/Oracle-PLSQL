# Functions: uso em SQL, DETERMINISTIC, RESULT_CACHE

Function é como procedure, mas **devolve um valor** com `RETURN` e pode ser usada dentro de uma expressão, inclusive em SQL.

```sql
CREATE OR REPLACE FUNCTION valor_pedido (p_id_pedido IN pedidos.id_pedido%TYPE)
    RETURN NUMBER
IS
    v_total NUMBER;
BEGIN
    SELECT SUM(ROUND(quantidade * preco_unitario * (1 - pct_desconto / 100), 2))
      INTO v_total
      FROM itens_pedido
     WHERE id_pedido = p_id_pedido;
    RETURN v_total;
END valor_pedido;
/

SELECT id_pedido, valor_pedido(id_pedido) FROM pedidos;
```

- O tipo do `RETURN` também vai sem tamanho.
- Todo caminho de execução precisa chegar a um `RETURN`; se a function terminar sem ele, dá ORA-06503 em tempo de execução.
- `RETURN` encerra a function na hora, mesmo dentro de laço.

## Regras para usar em SQL

| Restrição | Erro se violar |
|---|---|
| Sem DML (`INSERT`, `UPDATE`, `DELETE`) quando chamada por `SELECT` | ORA-14551 |
| Sem `COMMIT`/`ROLLBACK` | ORA-14552 |
| Só parâmetros `IN` | ORA-06572 |
| Tipos que o SQL conhece (BOOLEAN só a partir do `[23ai+]`) | ORA-06553 (com PLS-00382) |

Uma function chamada por um `UPDATE` também não pode ler ou alterar a tabela que está sendo atualizada (ORA-04091, a mesma "tabela mutante" do tópico 05).

## O custo de chamar PL/SQL a partir do SQL

Cada chamada é uma troca de contexto entre o motor SQL e o motor PL/SQL. Numa consulta de um milhão de linhas, são um milhão de trocas, e a function com `SELECT` por dentro vira um milhão de consultas extras (as consultas internas também não enxergam a consistência de leitura da consulta externa: veem os dados no momento de cada chamada).

Antes de escrever a function, veja se um JOIN ou uma subconsulta resolve. Quando a function é a escolha certa (regra reutilizada em muitos lugares), há quatro formas de reduzir o custo:

| Recurso | O que faz |
|---|---|
| Subconsulta escalar `(SELECT f(x) FROM dual)` | O Oracle guarda em cache os resultados por valor de entrada durante a consulta; entrada repetida não chama de novo. Não é garantido, mas costuma funcionar bem com poucos valores distintos. |
| `DETERMINISTIC` | Declara que a mesma entrada sempre dá a mesma saída. Permite ao Oracle reaproveitar resultados dentro de uma busca e é **obrigatório** para usar a function em índice baseado em função ou coluna virtual (ORA-30553 sem ele). |
| `PRAGMA UDF` `[12c+]` | Compila a function otimizada para ser chamada a partir de SQL; reduz o custo da troca de contexto. |
| `WITH FUNCTION` `[12c+]` | Function declarada dentro da própria consulta, só para ela. |

`DETERMINISTIC` é uma promessa: o Oracle não verifica. Function que lê tabela e é marcada como DETERMINISTIC pode devolver valor velho num índice ou num cache.

## RESULT_CACHE

```sql
CREATE OR REPLACE FUNCTION nome_categoria (p_id NUMBER) RETURN VARCHAR2
    RESULT_CACHE
IS ...
```

O resultado fica numa área compartilhada da SGA, **para todas as sessões**, até que uma tabela usada pela function sofra COMMIT de alteração (a partir do 11gR2 a dependência é detectada sozinha; a cláusula `RELIES_ON` é obsoleta). Bom para tabelas de consulta que mudam pouco (categorias, parâmetros). Ruim para dados que mudam o tempo todo: cada COMMIT invalida o cache, e há disputa de latch em alta concorrência.

Depende do parâmetro `RESULT_CACHE_MAX_SIZE` maior que zero. No Oracle Free e em bancos autônomos, pode estar desligado ou limitado.

## Function ou procedure?

- Calcula e devolve um valor, sem efeito colateral: **function**.
- Altera dados, ou devolve vários resultados: **procedure** com `OUT`.
- Function com parâmetro `OUT` é permitida em PL/SQL, mas não pode ser usada em SQL e confunde quem lê.

## Documentação oficial

- [PL/SQL Language Reference — CREATE FUNCTION Statement](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/CREATE-FUNCTION-statement.html)
- [PL/SQL Language Reference — PL/SQL Function Result Cache](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-subprograms.html)
- [PL/SQL Language Reference — UDF Pragma](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/UDF-pragma.html)
- [SQL Language Reference — SELECT, plsql_declarations (WITH FUNCTION)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SELECT.html)
