# Identificadores

## Regras

Identificador é o nome de um objeto (tabela, coluna, índice, procedure) ou de uma variável em PL/SQL. Sem aspas, ele precisa:

- começar com letra;
- conter só letras, números, `_`, `$` e `#` (a Oracle recomenda não usar `$` e `#`);
- ter até **128 bytes** a partir do 12.2 (até o 12.1, o limite era 30); passar disso dá ORA-00972;
- não ser palavra reservada (`SELECT`, `TABLE`, `DATE`, `LEVEL`, `NUMBER`...).

## Maiúsculas e minúsculas

Sem aspas, o Oracle **converte o nome para maiúsculas** ao gravar no dicionário. `CREATE TABLE clientes` cria `CLIENTES`; depois disso, `clientes`, `Clientes` e `CLIENTES` são o mesmo objeto.

Por isso, consultas ao dicionário de dados usam maiúsculas:

```sql
-- encontra
SELECT column_name FROM user_tab_columns WHERE table_name = 'CLIENTES';
-- não encontra
SELECT column_name FROM user_tab_columns WHERE table_name = 'clientes';
```

## Identificadores entre aspas

Com aspas duplas, o nome é gravado **exatamente como escrito**: diferencia maiúsculas, aceita espaço, acento e palavra reservada.

```sql
CREATE TABLE "Itens do Pedido" ("Data" DATE, "valor" NUMBER);
```

A partir daí, todo acesso precisa repetir as aspas e a grafia exata: `SELECT "valor" FROM "Itens do Pedido"`. Sem aspas, `valor` vira `VALOR`, que não existe.

**Não use aspas em nomes de objeto.** Elas aparecem em sistemas migrados de outros bancos e em ferramentas que geram DDL; quando aparecerem, o sintoma é ORA-00904 ou ORA-00942 para um objeto que "está lá".

## Nomes qualificados

`schema.objeto` acessa um objeto de outro schema; `tabela.coluna` ou `alias.coluna` desambigua colunas em joins; `objeto@dblink` acessa outro banco. Em consultas com mais de uma tabela, qualifique **todas** as colunas com o alias: uma coluna nova com o mesmo nome em outra tabela pode tornar a consulta ambígua (ORA-00918) ou, pior, mudar seu sentido.

## Espaço de nomes

Dentro de um schema, **tabelas, views, sequences, synonyms privados, procedures, functions, packages e tipos** compartilham o mesmo espaço de nomes: não dá para ter uma tabela e uma procedure chamadas `clientes`. Índices, constraints, triggers e database links têm espaço próprio.

## Convenção usada no repositório

| Objeto | Padrão | Exemplo |
|---|---|---|
| Tabela | substantivo no plural, `snake_case` | `itens_pedido` |
| Chave primária | `id_` + singular | `id_cliente` |
| Constraint | `pk_`, `uk_`, `fk_`, `ck_` + tabela + coluna | `fk_pedidos_cliente` |
| Índice | `ix_` + tabela + coluna | `ix_pedidos_data` |
| Objeto temporário de exemplo | `tmp_` | `tmp_tipos` |
| Variável PL/SQL | `v_`, parâmetro `p_`, constante `c_`, cursor `cur_` | `v_total` |

## Armadilhas

- **Nome de coluna igual a palavra reservada** (`DATE`, `LEVEL`, `SIZE`, `COMMENT`, `UID`) só é possível com aspas e gera problema em toda consulta. A lista está em `V$RESERVED_WORDS` (coluna `RESERVED = 'Y'`).
- **Constraint sem nome.** O Oracle gera `SYS_C0012345`, que muda de um ambiente para outro e não diz nada na mensagem de erro. Sempre nomeie.
- **Limite de 30 bytes em ambiente antigo.** Nomes longos criados no 19c não podem ser levados para um banco 12.1.

## Documentação oficial

- [SQL Language Reference — Database Object Names and Qualifiers](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Database-Object-Names-and-Qualifiers.html)
