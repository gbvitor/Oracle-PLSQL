# Comentários nos objetos e extração de DDL com DBMS_METADATA

## COMMENT ON

Documenta tabelas e colunas **dentro do banco**, onde a documentação acompanha o objeto em qualquer ambiente e aparece nas ferramentas gráficas.

```sql
COMMENT ON TABLE  pedidos             IS 'Cabecalho do pedido de venda';
COMMENT ON COLUMN pedidos.id_vendedor IS 'Funcionario que fez a venda; nulo para venda pelo site';
-- remove o comentário
COMMENT ON COLUMN pedidos.id_vendedor IS '';
```

Leitura: `USER_TAB_COMMENTS` (tabelas e views) e `USER_COL_COMMENTS` (colunas). `COMMENT` é DDL: faz commit.

O que vale comentar: o significado de códigos (`'S'/'N'`, status), a unidade (percentual cheio ou fração, centavos ou reais), o que um NULL significa, e de onde vem o dado quando ele é carregado de outro sistema.

## DBMS_METADATA.GET_DDL

Devolve o comando `CREATE` completo de um objeto existente, como `CLOB`:

```sql
SELECT DBMS_METADATA.GET_DDL('TABLE', 'PEDIDOS') FROM dual;
SELECT DBMS_METADATA.GET_DDL('VIEW', 'VW_VENDAS') FROM dual;
SELECT DBMS_METADATA.GET_DDL('PROCEDURE', 'PRC_X') FROM dual;
-- especificação e corpo
SELECT DBMS_METADATA.GET_DDL('PACKAGE', 'PKG_X') FROM dual;
-- só o corpo
SELECT DBMS_METADATA.GET_DDL('PACKAGE_BODY', 'PKG_X') FROM dual;
SELECT DBMS_METADATA.GET_DDL('TABLE', 'PEDIDOS', 'OUTRO_SCHEMA') FROM dual;
```

Tipos usados no primeiro argumento: `TABLE`, `VIEW`, `INDEX`, `SEQUENCE`, `SYNONYM`, `MATERIALIZED_VIEW`, `PROCEDURE`, `FUNCTION`, `PACKAGE`, `PACKAGE_SPEC`, `PACKAGE_BODY`, `TRIGGER`, `TYPE`, `CONSTRAINT`, `REF_CONSTRAINT`, `USER`, `ROLE`.

### Objetos dependentes

```sql
SELECT DBMS_METADATA.GET_DEPENDENT_DDL('INDEX',          'PEDIDOS') FROM dual;
SELECT DBMS_METADATA.GET_DEPENDENT_DDL('COMMENT',        'PEDIDOS') FROM dual;
SELECT DBMS_METADATA.GET_DEPENDENT_DDL('REF_CONSTRAINT', 'PEDIDOS') FROM dual;
SELECT DBMS_METADATA.GET_DEPENDENT_DDL('TRIGGER',        'PEDIDOS') FROM dual;
SELECT DBMS_METADATA.GET_DEPENDENT_DDL('OBJECT_GRANT',   'PEDIDOS') FROM dual;
```

Se não houver nenhum objeto daquele tipo, a função dá **ORA-31608** em vez de devolver vazio. Para varrer muitos objetos, trate esse erro ou confira antes no dicionário.

### Controlar o formato

`SET_TRANSFORM_PARAM` ajusta o texto gerado na sessão:

```sql
BEGIN
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SEGMENT_ATTRIBUTES', FALSE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE', FALSE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'SQLTERMINATOR', TRUE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'PRETTY', TRUE);
    DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM, 'CONSTRAINTS_AS_ALTER', TRUE);
END;
/
```

| Parâmetro | Efeito |
|---|---|
| `SEGMENT_ATTRIBUTES` = FALSE | Tira tablespace, `PCTFREE`, `LOGGING` etc.: DDL portável entre ambientes |
| `STORAGE` = FALSE | Tira a cláusula `STORAGE` |
| `SQLTERMINATOR` = TRUE | Acrescenta `;` (ou `/` para PL/SQL) no fim, pronto para rodar como script |
| `CONSTRAINTS_AS_ALTER` = TRUE | Gera as constraints como `ALTER TABLE` separados, depois do `CREATE` |
| `EMIT_SCHEMA` = FALSE `[12.2+]` | Omite o nome do schema (`"ESTUDO".`) |
| `DEFAULT` | `SET_TRANSFORM_PARAM(..., 'DEFAULT')` volta tudo ao padrão |

### Por que GET_DDL e não USER_SOURCE

`USER_SOURCE` guarda o texto de código PL/SQL linha a linha, sem o `CREATE OR REPLACE` montado do jeito que precisa ser executado e sem nada sobre tabelas, índices ou grants. `GET_DDL` devolve o comando completo e executável, para qualquer tipo de objeto, com o mesmo formato que o Data Pump usaria. Para comparar versões de código, versionar objetos num repositório ou levar um objeto de homologação para produção, `GET_DDL` é a fonte mais confiável.

## No SQL*Plus / SQLcl

O resultado é `CLOB`. Para ver o texto inteiro:

```sql
SET LONG 1000000
SET LONGCHUNKSIZE 1000000
SET PAGESIZE 0
SET LINESIZE 32767
```

No SQLcl, o comando `DDL nome_objeto` faz o mesmo de forma direta (seção 12).

## Documentação oficial

- [SQL Language Reference — COMMENT](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/COMMENT.html)
- [PL/SQL Packages and Types Reference — DBMS_METADATA](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_METADATA.html)
