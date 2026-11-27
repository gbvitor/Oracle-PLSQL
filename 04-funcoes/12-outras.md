# Outras funções úteis

## Comparação entre valores da mesma linha

| Função | Devolve |
|---|---|
| `GREATEST(a, b, ...)` | O maior dos argumentos |
| `LEAST(a, b, ...)` | O menor |

Diferente de `MAX`/`MIN`, que comparam **linhas**, estas comparam **argumentos** dentro da mesma linha: "a maior entre a data de cadastro e a data do último pedido".

Duas regras que surpreendem:

- **Se qualquer argumento for NULL, o resultado é NULL.** Para ignorar nulos: `GREATEST(NVL(a, b), NVL(b, a))`, ou `COALESCE` com valores de referência.
- **O tipo vem do primeiro argumento.** `GREATEST('10', 9)` compara como **texto** (`'9' > '10'`) e devolve `'9'`. `GREATEST(10, '9')` compara como número e devolve `10`.

## Identificadores e hash

| Função | Devolve | Uso |
|---|---|---|
| `SYS_GUID()` | `RAW(16)` único globalmente | Chave substituta que não depende de sequence; em texto, `RAWTOHEX(SYS_GUID())` |
| `ORA_HASH(expr [, max_bucket [, seed]])` | Número de 0 a `max_bucket` | Distribuir linhas em grupos de forma estável (amostra reproduzível, divisão de carga entre processos) |
| `STANDARD_HASH(expr [, 'SHA256'])` `[12c+]` | `RAW` com o hash (`SHA1` padrão; `SHA256`, `SHA384`, `SHA512`, `MD5`) | Comparar conteúdo, detectar mudança, pseudonimizar |

`ORA_HASH` não é criptográfico: serve para distribuir, não para proteger. Para dados pessoais, `STANDARD_HASH` com `SHA256` e, se o objetivo é impedir reversão por força bruta (CPF tem poucos valores possíveis), concatenando um valor secreto antes do hash.

## Contexto da sessão

| Função | Devolve |
|---|---|
| `USER` | Usuário conectado |
| `SYS_CONTEXT('USERENV', 'parâmetro')` | Informações da sessão: `CURRENT_SCHEMA`, `SESSION_USER`, `OS_USER`, `HOST`, `IP_ADDRESS`, `MODULE`, `CLIENT_IDENTIFIER`, `CON_NAME`, `DB_NAME`, `SID`, `LANG` |

Muito usado em triggers de auditoria para registrar quem e de onde fez a alteração (seção 15).

## Inspeção de valores

| Função | Devolve |
|---|---|
| `DUMP(expr [, formato])` | Tipo interno, tamanho e bytes do valor (`DUMP(x, 1016)` mostra em hexadecimal com o conjunto de caracteres) |
| `VSIZE(expr)` | Bytes ocupados pelo valor |

Úteis para investigar caractere invisível (espaço não separável, quebra de linha, tabulação) que faz uma comparação falhar.

## Números aleatórios (pacote DBMS_RANDOM)

| Chamada | Devolve |
|---|---|
| `DBMS_RANDOM.VALUE` | Número em [0, 1) |
| `DBMS_RANDOM.VALUE(a, b)` | Número em [a, b) |
| `DBMS_RANDOM.STRING('U', n)` | Texto aleatório: `'U'` maiúsculas, `'L'` minúsculas, `'A'` letras, `'X'` maiúsculas e dígitos, `'P'` imprimíveis |
| `DBMS_RANDOM.SEED(n)` | Fixa a semente para repetir a sequência |

Para gerar massa de teste. Não é adequado para senha ou token: para isso, `DBMS_CRYPTO.RANDOMBYTES` (exige privilégio de execução no pacote).

## Documentação oficial

- [SQL Language Reference — GREATEST](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/GREATEST.html)
- [SQL Language Reference — STANDARD_HASH](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/STANDARD_HASH.html)
- [SQL Language Reference — SYS_CONTEXT](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SYS_CONTEXT.html)
- [PL/SQL Packages and Types Reference — DBMS_RANDOM](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_RANDOM.html)
