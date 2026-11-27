# Funções de texto

## Referência

| Função | O que faz | Exemplo | Resultado |
|---|---|---|---|
| `UPPER(s)` / `LOWER(s)` | Maiúsculas / minúsculas | `UPPER('ana')` | `ANA` |
| `INITCAP(s)` | Primeira letra de cada palavra em maiúscula | `INITCAP('ANA RIBEIRO')` | `Ana Ribeiro` |
| `LENGTH(s)` | Tamanho em caracteres | `LENGTH('Oracle')` | `6` |
| `LENGTHB(s)` | Tamanho em bytes | `LENGTHB('ação')` | `6` em AL32UTF8 |
| `SUBSTR(s, pos [, qtd])` | Trecho a partir de `pos` | `SUBSTR('Oracle', 2, 3)` | `rac` |
| `SUBSTR(s, -n)` | Últimos `n` caracteres | `SUBSTR('Oracle', -3)` | `cle` |
| `INSTR(s, busca [, pos [, ocorrência]])` | Posição da ocorrência (0 se não achar) | `INSTR('a.b.c', '.', 1, 2)` | `4` |
| `INSTR(s, busca, -1)` | Busca de trás para frente | `INSTR('a.b.c', '.', -1)` | `4` |
| `TRIM(s)` | Remove espaços das pontas | `TRIM('  x  ')` | `x` |
| `TRIM(LEADING '0' FROM s)` | Remove um caractere do início (`TRAILING`, `BOTH`) | `TRIM(LEADING '0' FROM '00120')` | `120` |
| `LTRIM(s, conjunto)` / `RTRIM` | Remove do início / fim **qualquer** caractere do conjunto | `RTRIM('12.500', '0.')` | `12.5` |
| `LPAD(s, n [, c])` / `RPAD` | Completa até `n` à esquerda / direita | `LPAD('42', 5, '0')` | `00042` |
| `REPLACE(s, de, para)` | Troca uma sequência por outra | `REPLACE('a-b-c', '-', '')` | `abc` |
| `TRANSLATE(s, de, para)` | Troca caractere a caractere | `TRANSLATE('ação', 'çã', 'ca')` | `acao` |
| `CONCAT(a, b)` | Concatena dois textos | `CONCAT('a', 'b')` | `ab` |
| `ASCII(c)` / `CHR(n)` | Código do caractere / caractere do código | `CHR(10)` | quebra de linha |
| `UNISTR(s)` | Texto a partir de códigos Unicode | `UNISTR('\00E7')` | `ç` |

## Comportamentos que surpreendem

- **`LPAD` e `RPAD` cortam** quando o texto é maior que o tamanho pedido: `LPAD('12345', 3)` = `'123'`.
- **`LTRIM`/`RTRIM` com segundo argumento** removem um **conjunto** de caracteres, não uma sequência: `RTRIM('Ltda.', '.adt')` = `'L'`.
- **`TRANSLATE` remove** os caracteres do "de" que não têm correspondente no "para": `TRANSLATE('a-b', 'a-', 'A')` = `'Ab'`. É útil para limpar: `TRANSLATE(doc, '0./-', '0')` remove ponto, barra e hífen.
- **`REPLACE` sem terceiro argumento** remove: `REPLACE('1.234.567', '.')` = `'1234567'`.
- **`SUBSTR` com posição 0** é tratado como 1.
- **`INSTR` devolve 0** quando não encontra, não NULL; `SUBSTR(s, INSTR(...))` com 0 devolve o texto inteiro.
- **`INITCAP`** coloca maiúscula depois de qualquer caractere não alfanumérico: `INITCAP('joão d''ávila')` muda também a letra depois do apóstrofo.
- Todas devolvem NULL se o texto é NULL (exceto `REPLACE` e `CONCAT`, que tratam NULL como vazio).

## Tirar acentos

Não há função dedicada. As opções:

```sql
-- TRANSLATE com as listas completas (funciona em qualquer versão)
TRANSLATE(nome, 'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇáàâãäéèêëíìîïóòôõöúùûüç',
                'AAAAAEEEEIIIIOOOOOUUUUCaaaaaeeeeiiiiooooouuuuc')

-- NLSSORT/comparação linguística para COMPARAR sem acento, sem alterar o texto
WHERE NLSSORT(nome, 'NLS_SORT = BINARY_AI') = NLSSORT('Joao', 'NLS_SORT = BINARY_AI')
```

## Documentação oficial

- [SQL Language Reference — Character Functions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Single-Row-Functions.html)
