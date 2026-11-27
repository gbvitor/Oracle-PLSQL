# Funções de expressão regular

A sintaxe dos padrões e a condição `REGEXP_LIKE` estão na seção 03, tópico 13.

## Referência

| Função | Devolve |
|---|---|
| `REGEXP_SUBSTR(s, padrao [, pos [, ocorrencia [, parametros [, subexpressao]]]])` | O trecho que casa com o padrão |
| `REGEXP_INSTR(s, padrao [, pos [, ocorrencia [, opcao [, parametros [, subexpressao]]]]])` | A posição do trecho (0 se não achar); `opcao = 1` devolve a posição **depois** do trecho |
| `REGEXP_REPLACE(s, padrao [, troca [, pos [, ocorrencia [, parametros]]]])` | O texto com as ocorrências trocadas; `ocorrencia = 0` (padrão) troca todas |
| `REGEXP_COUNT(s, padrao [, pos [, parametros]])` | Quantas vezes o padrão aparece |

**Subexpressão**: o trecho entre parênteses de número `n` no padrão. Em `REGEXP_SUBSTR`, o último argumento escolhe qual devolver. Em `REGEXP_REPLACE`, `\1`, `\2`... no texto de troca reaproveitam esses trechos.

## Usos comuns

| Necessidade | Expressão |
|---|---|
| Só os dígitos | `REGEXP_REPLACE(doc, '[^0-9]')` |
| Formatar CPF | `REGEXP_REPLACE(cpf, '^(\d{3})(\d{3})(\d{3})(\d{2})$', '\1.\2.\3-\4')` |
| Espaços repetidos viram um | `REGEXP_REPLACE(s, ' {2,}', ' ')` |
| N-ésimo item de uma lista | `REGEXP_SUBSTR(lista, '[^,]+', 1, n)` |
| Quantidade de palavras | `REGEXP_COUNT(s, '\S+')` |
| Primeiro número do texto | `REGEXP_SUBSTR(s, '\d+')` |

## Quebrar texto delimitado em linhas

```sql
SELECT REGEXP_SUBSTR(lista, '[^,]+', 1, LEVEL) AS item
  FROM (SELECT 'SP,MG,GO' AS lista FROM dual)
CONNECT BY LEVEL <= REGEXP_COUNT(lista, ',') + 1;
```

Com `'[^,]+'`, itens vazios (`'SP,,GO'`) são **pulados**, e a posição dos seguintes muda. Para preservar vazios: `REGEXP_SUBSTR(lista, '([^,]*)(,|$)', 1, LEVEL, NULL, 1)`.

Para várias linhas de origem, o `CONNECT BY LEVEL` precisa ficar dentro de um `LATERAL` ou `CROSS APPLY` por linha; sem isso, as linhas se combinam entre si e o resultado explode.

## Limitações do Oracle

- **Não há `\b`** (limite de palavra), nem lookahead/lookbehind (`(?=...)`). Simule o limite com `(^|[^[:alnum:]])` e use subexpressão para pegar só a parte desejada.
- Quantificadores preguiçosos (`*?`, `+?`) são aceitos.
- Expressões regulares são mais lentas que `INSTR`/`SUBSTR`/`REPLACE`. Para trocas simples de texto fixo, prefira as funções comuns.

## Documentação oficial

- [SQL Language Reference — REGEXP_SUBSTR](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/REGEXP_SUBSTR.html)
- [SQL Language Reference — REGEXP_REPLACE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/REGEXP_REPLACE.html)
