# SELECT e DISTINCT

## Sintaxe

```sql
SELECT [ DISTINCT | UNIQUE | ALL ] lista_de_selecao
  FROM ...
```

A lista de seleção pode ter:

| Item | Exemplo |
|---|---|
| Todas as colunas | `SELECT *` |
| Todas as colunas de uma tabela do join | `SELECT p.*, c.nome` |
| Coluna | `SELECT nome` |
| Expressão | `SELECT salario * 12` |
| Função | `SELECT UPPER(nome)` |
| Subquery escalar | `SELECT (SELECT COUNT(*) FROM pedidos p WHERE p.id_cliente = c.id_cliente)` |
| Literal | `SELECT 'ativo'` |

## Alias de coluna

```sql
SELECT salario * 12 AS salario_anual,    -- com AS
       salario * 12    anual,            -- sem AS: também vale
       salario * 12 AS "Salário Anual"   -- com aspas: mantém maiúsculas, espaço e acento
  FROM funcionarios;
```

- Sem aspas, o alias aparece em maiúsculas no resultado (`SALARIO_ANUAL`).
- O alias pode ser usado no `ORDER BY`, mas não no `WHERE`, `GROUP BY` (até o 19c) ou `HAVING` (tópico 09 da seção 01).
- Quando a consulta vira inline view, toda expressão precisa de alias para ser referenciada de fora.

## DISTINCT

Remove linhas **repetidas no resultado**, considerando todas as colunas selecionadas juntas. `UNIQUE` é sinônimo do Oracle; `ALL` é o padrão (não remove nada).

```sql
-- cada cargo uma vez
SELECT DISTINCT cargo FROM funcionarios;

-- cada combinação cidade + UF uma vez
SELECT DISTINCT cidade, uf FROM clientes;
```

- Dois NULLs são considerados iguais: aparecem uma vez só.
- `COUNT(DISTINCT coluna)` conta valores distintos, ignorando NULL.
- O Oracle precisa ordenar ou agrupar por hash para eliminar repetidos. Em tabela grande, isso custa.

## Quando usar e quando evitar

`SELECT *` serve para explorar uma tabela. Em código que fica (view, procedure, relatório), liste as colunas: uma coluna nova na tabela muda o resultado, pode quebrar `INSERT ... SELECT *` e traz dados que ninguém pediu.

`DISTINCT` é correto quando a pergunta é sobre valores distintos ("quais UFs têm cliente?"). É sintoma de problema quando aparece para "consertar" linha duplicada vinda de um join: a duplicação geralmente indica que o join está numa granularidade diferente da pergunta.

## Armadilhas

- **DISTINCT para esconder join errado.** "Clientes que têm pedido" com `JOIN pedidos` + `DISTINCT` funciona, mas monta todas as combinações cliente × pedido para depois descartar. `WHERE EXISTS` responde a mesma pergunta sem multiplicar linhas.
- **DISTINCT com coluna a mais.** `SELECT DISTINCT id_cliente, data_pedido` não dá "clientes distintos"; dá combinações distintas de cliente e data.
- **DISTINCT em CLOB** não é permitido (ORA-00932).

## Documentação oficial

- [SQL Language Reference — SELECT](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SELECT.html)
