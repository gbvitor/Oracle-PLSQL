# REGEXP_LIKE

## Sintaxe

```sql
REGEXP_LIKE(texto, padrao [, parametros])
```

Verdadeiro se o texto contém uma ocorrência da expressão regular. É uma **condição** (vai no `WHERE`, `CASE`, `CHECK`), não uma função que devolve valor. As funções `REGEXP_SUBSTR`, `REGEXP_INSTR`, `REGEXP_REPLACE` e `REGEXP_COUNT` estão na seção 04.

## Parâmetros de busca

| Parâmetro | Efeito |
|---|---|
| `'i'` | Ignora maiúsculas e minúsculas |
| `'c'` | Diferencia (padrão, salvo configuração NLS) |
| `'n'` | O `.` também casa com quebra de linha |
| `'m'` | `^` e `$` valem para cada linha do texto, não só início e fim |
| `'x'` | Ignora espaços no padrão |

## Elementos de padrão mais usados

| Elemento | Significa |
|---|---|
| `^` / `$` | Início / fim do texto |
| `.` | Qualquer caractere |
| `*` `+` `?` | 0 ou mais, 1 ou mais, 0 ou 1 |
| `{n}` `{n,}` `{n,m}` | Exatamente n, pelo menos n, entre n e m |
| `[abc]` / `[^abc]` | Um dos caracteres / nenhum deles |
| `[a-z]`, `[0-9]` | Faixa |
| `[[:digit:]]`, `[[:alpha:]]`, `[[:upper:]]`, `[[:space:]]` | Classes POSIX |
| `\d`, `\w`, `\s` | Dígito, caractere de palavra, espaço (extensões aceitas pelo Oracle) |
| `(a\|b)` | Alternativa |
| `\.` | Ponto literal (qualquer metacaractere com `\` vira literal) |

Sem `^` e `$`, o padrão pode estar **em qualquer parte** do texto: `REGEXP_LIKE(documento, '[0-9]{11}')` é verdadeiro também para um texto de 14 dígitos. Para validar o valor inteiro, ancore: `'^[0-9]{11}$'`.

## Usos

- **Validação de formato** em consulta de auditoria ou em `CHECK`: só dígitos, tamanho exato, e-mail com estrutura mínima, placa, CEP.
- **Busca flexível** que o `LIKE` não alcança: alternativas (`Ltda|ME|SA`), classes de caracteres, repetições.

```sql
ALTER TABLE clientes ADD CONSTRAINT ck_clientes_documento_formato
    CHECK (REGEXP_LIKE(documento, '^([0-9]{11}|[0-9]{14})$'));
```

## Desempenho

`REGEXP_LIKE` não usa índice comum e é mais caro que `LIKE` por linha. Em tabela grande, combine com um filtro que use índice, ou use `LIKE` quando o padrão for simples.

## Armadilhas

- **Esquecer as âncoras** e aceitar textos maiores do que o formato.
- **Ponto sem escape.** Em `'^.+@.+.com$'`, o último `.` casa com qualquer caractere.
- **Expressão regular de e-mail "completa".** Validação de e-mail por regex é sempre aproximada; use um padrão simples para pegar erros grosseiros, não para garantir que o endereço existe.

## Documentação oficial

- [SQL Language Reference — REGEXP_LIKE Condition](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Pattern-matching-Conditions.html)
- [Development Guide — Using Regular Expressions in Database Applications](https://docs.oracle.com/en/database/oracle/oracle-database/19/adfns/regexp.html)
