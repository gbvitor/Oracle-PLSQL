# Records

Um record agrupa vários campos de tipos diferentes numa variável só, como uma linha. Três formas de declarar:

```sql
-- Mesma estrutura de uma tabela (ou view)
r_cliente clientes%ROWTYPE;

-- Mesma estrutura do resultado de um cursor
CURSOR c_resumo IS SELECT id_cliente, nome, uf FROM clientes;
r_resumo c_resumo%ROWTYPE;

-- Tipo próprio
TYPE t_resumo_cliente IS RECORD (
    id_cliente  clientes.id_cliente%TYPE,
    nome        clientes.nome%TYPE,
    qtd_pedidos PLS_INTEGER := 0,
    total       NUMBER NOT NULL := 0
);
r t_resumo_cliente;
```

- Campos são acessados com ponto: `r.nome`.
- Campo `NOT NULL` precisa de valor inicial.
- Um campo pode ser outro record (record aninhado: `r.endereco.cidade`) ou uma coleção (seção 09, tópico 07).
- `%ROWTYPE` acompanha a tabela: coluna nova aparece no record na próxima compilação. Em contrapartida, `SELECT * INTO r_cliente` quebra se o record e a consulta não tiverem as mesmas colunas, na mesma ordem.

## Atribuição

| Operação | Permitido? |
|---|---|
| `r2 := r1;` com o mesmo tipo `RECORD` | Sim |
| `r2 := r1;` com tipos `RECORD` diferentes, mesmo que tenham campos iguais | Não (PLS-00382) |
| Destino `RECORD`, origem `%ROWTYPE`, com campos na mesma quantidade, ordem e tipo | Sim |
| `SELECT ... INTO r` e `FETCH c INTO r` | Sim, pela ordem das colunas |
| Expressão qualificada `t_resumo_cliente(id_cliente => 1, nome => 'X', ...)` `[18c+]` | Sim |

**Comparar records com `=` não funciona** (PLS-00306). Compare campo a campo, lembrando que NULL não é igual a NULL.

Para "zerar" um record (todos os campos NULL, ou os valores iniciais do tipo), atribua um record do mesmo tipo que nunca foi preenchido.

## Records em DML

```sql
INSERT INTO tmp_clientes VALUES r_cliente;

UPDATE tmp_clientes
   SET ROW = r_cliente
 WHERE id_cliente = r_cliente.id_cliente;

UPDATE tmp_clientes
   SET limite_credito = limite_credito * 1.1
 WHERE id_cliente = 3
RETURNING id_cliente, nome, limite_credito INTO r_retorno;
```

- `INSERT ... VALUES r` exige record `%ROWTYPE` da tabela (ou com os mesmos campos na mesma ordem). Não há lista de colunas.
- `SET ROW = r` regrava **todas** as colunas, inclusive a chave primária, com o que estiver no record. Atualiza índices e dispara triggers de colunas que nem mudaram de valor. Use quando a linha inteira veio do record; para mudar uma ou duas colunas, `SET coluna = r.campo`.
- `RETURNING ... INTO r` lê os valores gravados sem um `SELECT` extra.

## Quando usar

- `%ROWTYPE` e `cursor%ROWTYPE`: para carregar uma linha e passar adiante.
- `RECORD` próprio: para resultado montado (resumo, parâmetro com vários campos, retorno de função com mais de um valor).
- Record é a base das coleções de records (`TABLE OF t_resumo_cliente`) usadas com `BULK COLLECT` (seção 09).

## Documentação oficial

- [PL/SQL Language Reference — Record Variables](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-collections-and-records.html)
- [PL/SQL Language Reference — Inserting Records into Tables / Updating Rows with Records](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-collections-and-records.html)
