# RETURNING INTO

## O que faz

Devolve valores das linhas afetadas por um `INSERT`, `UPDATE` ou `DELETE`, no mesmo comando, sem precisar de um `SELECT` depois.

```sql
INSERT INTO tmp_pedidos (id_cliente, data_pedido)
VALUES (1, SYSDATE)
RETURNING id_pedido INTO v_id;
```

Usos principais:

- **Pegar a chave gerada** (coluna `IDENTITY`, sequence em trigger, `DEFAULT`) logo depois do `INSERT`.
- **Saber o valor final** de uma coluna depois de um `UPDATE` calculado (`SET preco = preco * 1.05`).
- **Registrar o que foi apagado** num `DELETE`, para log ou auditoria.

Além de economizar uma ida ao banco, evita a condição de corrida de fazer `SELECT MAX(id)` depois do `INSERT`, que pode devolver o id de outra sessão.

## Onde usar

| Contexto | Destino |
|---|---|
| PL/SQL, uma linha | Variáveis: `RETURNING col1, col2 INTO v1, v2` |
| PL/SQL, várias linhas | Coleções: `RETURNING col BULK COLLECT INTO v_lista` |
| SQL*Plus / SQLcl | Variável de ligação: `VARIABLE v NUMBER` e `RETURNING ... INTO :v` |
| Aplicação (JDBC, Python) | Parâmetro de saída do driver |

Se o comando afetar mais de uma linha e o destino for variável simples, ocorre ORA-01422. Se afetar nenhuma linha, as variáveis ficam nulas (sem erro).

## Valores antigos e novos `[23ai+]`

No 19c, `RETURNING` num `UPDATE` devolve o valor **depois** da alteração. A partir do 23ai, `RETURNING OLD coluna, NEW coluna` devolve os dois.

## Restrições

- No 19c, `INSERT ... SELECT` não aceita `RETURNING`; só `INSERT ... VALUES`.
- Não funciona em tabela remota (`@dblink`).
- Colunas LOB podem ser devolvidas, mas como localizador.

## Documentação oficial

- [SQL Language Reference — INSERT (returning_clause)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/INSERT.html)
- [PL/SQL Language Reference — RETURNING INTO Clause](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/RETURNING-INTO-clause.html)
