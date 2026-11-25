# CASE

## Duas formas

**CASE simples**: compara uma expressão com uma lista de valores (só igualdade).

```sql
CASE tipo_pessoa
    WHEN 'F' THEN 'Pessoa fisica'
    WHEN 'J' THEN 'Pessoa juridica'
    ELSE 'Nao informado'
END
```

**CASE pesquisado**: cada `WHEN` tem uma condição completa (qualquer operador).

```sql
CASE
    WHEN salario <  3000 THEN 'ate 3 mil'
    WHEN salario <  6000 THEN '3 a 6 mil'
    WHEN salario < 10000 THEN '6 a 10 mil'
    ELSE '10 mil ou mais'
END
```

## Regras

- **O primeiro `WHEN` verdadeiro vence**, e os demais não são avaliados. A ordem das condições faz parte da lógica.
- **Sem `ELSE`, o resultado é NULL** quando nenhuma condição é verdadeira.
- **Todos os `THEN` e o `ELSE` precisam ter tipo compatível.** Misturar texto e número dá ORA-00932.
- `CASE` simples não reconhece NULL (`WHEN NULL` nunca é verdadeiro). Para isso, `CASE` pesquisado com `WHEN coluna IS NULL`, ou `DECODE`.
- É uma **expressão**: vale em `SELECT`, `WHERE`, `ORDER BY`, `GROUP BY`, `SET` de `UPDATE`, dentro de funções de agregação e em PL/SQL.

## Usos que valem conhecer

**Agregação condicional**: várias contagens ou somas, cada uma com seu filtro, numa linha só.

```sql
SELECT COUNT(CASE WHEN status = 'ABERTO'   THEN 1 END) AS abertos,
       COUNT(CASE WHEN status = 'ENTREGUE' THEN 1 END) AS entregues
  FROM pedidos;
```

`COUNT` ignora NULL, e o `CASE` sem `ELSE` devolve NULL para as outras linhas.

**Ordem de negócio** no `ORDER BY` (seção 02, tópico 06).

**Proteção contra erro**: como o `CASE` avalia em ordem e para no primeiro verdadeiro, ele garante que uma conversão só aconteça quando for segura, coisa que o `AND` do `WHERE` não garante.

```sql
WHERE CASE WHEN REGEXP_LIKE(codigo, '^\d+$') THEN TO_NUMBER(codigo) END > 100
```

**UPDATE com várias regras** num comando só:

```sql
UPDATE produtos
   SET preco_unitario = CASE id_categoria
                            WHEN 7 THEN preco_unitario * 1.10
                            WHEN 5 THEN preco_unitario * 1.03
                            ELSE preco_unitario
                        END;
```

## Armadilhas

- **Faixas na ordem errada.** `WHEN salario > 3000 ... WHEN salario > 10000 ...`: a segunda nunca é atingida.
- **Esquecer o `ELSE`** e gerar NULL que some de somas e contagens.
- **`ELSE 0` dentro de `COUNT`.** `COUNT(CASE WHEN ... THEN 1 ELSE 0 END)` conta todas as linhas, porque 0 não é NULL. Com `ELSE 0`, use `SUM`.

## Documentação oficial

- [SQL Language Reference — CASE Expressions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/CASE-Expressions.html)
