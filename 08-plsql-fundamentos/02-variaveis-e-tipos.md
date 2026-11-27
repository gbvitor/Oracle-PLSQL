# Variáveis, constantes, %TYPE e %ROWTYPE

## Declaração

```sql
DECLARE
    -- começa NULL
    v_nome      VARCHAR2(100);
    -- com valor inicial
    v_total     NUMBER(12,2) := 0;
    -- DEFAULT equivale a :=
    v_ativo     BOOLEAN DEFAULT TRUE;
    -- NOT NULL exige valor inicial
    v_contador  PLS_INTEGER NOT NULL := 0;
    -- constante: valor obrigatório e fixo
    c_taxa      CONSTANT NUMBER := 0.05;
```

- Toda variável sem valor inicial começa **NULL**, inclusive numéricas: `v_total + 1` dá NULL se `v_total` não foi inicializada.
- `:=` é atribuição; `=` é comparação.
- Uma declaração por linha. `DECLARE a, b NUMBER;` não é válido.

## Tipos mais usados

| Tipo | Observação |
|---|---|
| `VARCHAR2(n)` | Até 32767 bytes em PL/SQL (4000 em coluna de tabela, salvo `MAX_STRING_SIZE = EXTENDED`) |
| `NUMBER(p,s)` | Igual ao SQL |
| `PLS_INTEGER` | Inteiro de 32 bits, aritmética nativa, mais rápido que `NUMBER` em contadores e índices de laço. Estoura com ORA-01426 |
| `SIMPLE_INTEGER` `[11g+]` | `PLS_INTEGER NOT NULL` que **dá a volta** em vez de estourar; ainda mais rápido em código compilado nativamente |
| `BOOLEAN` | `TRUE`, `FALSE` ou NULL. Só existe em PL/SQL antes do 23ai: não pode ser coluna, nem ser devolvido para SQL |
| `DATE`, `TIMESTAMP` | Iguais ao SQL |
| `CLOB` | Texto grande |

## %TYPE e %ROWTYPE

Declaram uma variável **com o tipo de outra coisa**:

```sql
-- mesmo tipo e tamanho da coluna
v_nome     clientes.nome%TYPE;
-- um registro com todas as colunas da tabela
v_cliente  clientes%ROWTYPE;
-- mesmo tipo de outra variável
v_outro    v_nome%TYPE;
```

Vantagens: se a coluna passar de `VARCHAR2(100)` para `VARCHAR2(200)`, o código acompanha sem alteração (é recompilado automaticamente na próxima execução). Evita o erro clássico de declarar a variável menor que a coluna e ter ORA-06502 só com certos dados.

Detalhe: `%TYPE` de uma **coluna** não herda o `NOT NULL` da coluna; de uma **variável** declarada `NOT NULL`, herda.

## SUBTYPE

Dá nome a um tipo com restrição, para reuso:

```sql
SUBTYPE t_valor IS NUMBER(12,2);
SUBTYPE t_flag  IS VARCHAR2(1);
v_preco t_valor;
```

## Conversão e estouro

- Atribuir texto maior que a variável: **ORA-06502** (erro numérico ou de valor: buffer de string de caracteres pequeno demais).
- Atribuir número com mais dígitos inteiros que a precisão: ORA-06502.
- Atribuir texto não numérico a `NUMBER`: ORA-06502 (em SQL seria ORA-01722).

## Documentação oficial

- [PL/SQL Language Reference — PL/SQL Data Types](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-data-types.html)
- [PL/SQL Language Reference — %TYPE Attribute](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/TYPE-attribute.html)
