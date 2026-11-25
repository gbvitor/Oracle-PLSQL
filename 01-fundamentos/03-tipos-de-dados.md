# Tipos de dados

## Texto

| Tipo | Tamanho máximo | Uso |
|---|---|---|
| `VARCHAR2(n)` | 4000 bytes (32767 com `MAX_STRING_SIZE = EXTENDED`) | Padrão para texto. Guarda só o que foi informado |
| `CHAR(n)` | 2000 bytes | Tamanho fixo; completa com espaços à direita. Só para códigos de tamanho fixo (`uf`, `S`/`N`) |
| `NVARCHAR2(n)` / `NCHAR(n)` | idem, no conjunto de caracteres nacional | Quando o banco não é Unicode e uma coluna precisa ser |
| `CLOB` / `NCLOB` | Até terabytes | Texto longo (XML, JSON, observações extensas) |
| `LONG` `[legado]` | 2 GB | Substituído por `CLOB`; ainda aparece no dicionário de dados |

**Bytes ou caracteres.** `VARCHAR2(10)` significa, por padrão, 10 **bytes**. Num banco UTF-8 (`AL32UTF8`), letras acentuadas ocupam 2 bytes, então "ação" (4 caracteres) ocupa 6 bytes. Para limitar por caracteres: `VARCHAR2(10 CHAR)`. O padrão da sessão vem de `NLS_LENGTH_SEMANTICS`.

**String vazia é NULL.** No Oracle, `''` e `NULL` são a mesma coisa em `VARCHAR2`. `WHERE email = ''` nunca retorna linha; o certo é `WHERE email IS NULL`. Esse comportamento é diferente de PostgreSQL, SQL Server e MySQL.

## Números

| Tipo | Faixa | Uso |
|---|---|---|
| `NUMBER(p, s)` | `p` de 1 a 38 dígitos; `s` de −84 a 127 | Padrão para valores exatos: dinheiro, quantidade, código |
| `NUMBER` | Qualquer valor, precisão máxima | Quando não se quer limitar; evita erro, mas também não valida nada |
| `NUMBER(p)` | Inteiro de até `p` dígitos | Chaves e contadores |
| `INTEGER`, `INT`, `SMALLINT` | Sinônimos de `NUMBER(38)` | Compatibilidade ANSI |
| `BINARY_FLOAT` / `BINARY_DOUBLE` | Ponto flutuante IEEE 754 | Cálculo científico; nunca para dinheiro |
| `FLOAT(b)` | Subtipo de `NUMBER` com precisão binária | Raro |

Como `NUMBER(p, s)` se comporta:

- `p` é o total de dígitos significativos e `s` quantos ficam depois da vírgula. `NUMBER(5,2)` aceita de −999,99 a 999,99.
- Casas decimais a mais são **arredondadas** sem erro: 123,456 vira 123,46.
- Dígitos inteiros a mais geram **ORA-01438**: 1234,5 não cabe em `NUMBER(5,2)`.
- Escala negativa arredonda à esquerda da vírgula: `NUMBER(6,-2)` grava 123456 como 123500.

## Data e hora

| Tipo | Guarda | Observação |
|---|---|---|
| `DATE` | Ano, mês, dia, hora, minuto, segundo | **Sempre tem hora**, mesmo que a ferramenta não mostre. Sem fração de segundo e sem fuso |
| `TIMESTAMP(f)` | `DATE` + fração de segundo (até 9 casas; padrão 6) | Quando a ordem exata dos eventos importa |
| `TIMESTAMP(f) WITH TIME ZONE` | `TIMESTAMP` + fuso horário | Eventos de várias regiões |
| `TIMESTAMP(f) WITH LOCAL TIME ZONE` | Normaliza para o fuso do banco e exibe no fuso da sessão | Aplicações com usuários em fusos diferentes |
| `INTERVAL YEAR TO MONTH` | Período em anos e meses | Prazos contratuais |
| `INTERVAL DAY TO SECOND` | Período em dias, horas, minutos, segundos | Durações |

Aritmética: `DATE - DATE` retorna **número de dias** (com fração para as horas). `TIMESTAMP - TIMESTAMP` retorna um **INTERVAL DAY TO SECOND**. `DATE + 1` soma um dia; `DATE + 1/24` soma uma hora.

Literais que não dependem da configuração da sessão: `DATE '2026-11-25'`, `TIMESTAMP '2026-11-25 14:30:00'`, `INTERVAL '3' DAY`. Para data com hora em `DATE`, use `TO_DATE('2026-11-25 14:30', 'YYYY-MM-DD HH24:MI')`. Detalhes de conversão na seção 04.

## Binários e outros

| Tipo | Uso |
|---|---|
| `RAW(n)` | Binário curto (hash, GUID); até 2000 bytes |
| `BLOB` | Binário grande: PDF, imagem |
| `BFILE` | Ponteiro para arquivo no servidor, fora do banco |
| `ROWID` / `UROWID` | Endereço físico de uma linha (seção 01, tópico 06) |
| `XMLTYPE` | XML com validação e consulta |
| `JSON` `[21c+]` | JSON em formato binário nativo; no 19c, JSON é guardado em `VARCHAR2`/`CLOB`/`BLOB` com `CHECK (coluna IS JSON)` |
| `BOOLEAN` `[23ai+]` | Verdadeiro/falso em coluna de tabela; no 19c, usar `CHAR(1)` com `CHECK` ou `NUMBER(1)` |
| `VECTOR` `[23ai+]` | Vetores para busca por similaridade |

## Tipos só de PL/SQL

`BOOLEAN` (antes do 23ai, existia só em PL/SQL), `PLS_INTEGER`/`BINARY_INTEGER` (inteiro de 32 bits, mais rápido que `NUMBER` em laços) e tipos de coleção e registro. Vistos nas seções 08 e 09.

## Armadilhas

- **CHAR comparado com VARCHAR2.** Entre dois `CHAR` (ou `CHAR` e literal), o Oracle completa com espaços antes de comparar e `'SP' = 'SP   '` é verdadeiro. Entre `CHAR` e `VARCHAR2` (variável, bind, coluna), não completa, e a mesma comparação é falsa. É um dos motivos para evitar `CHAR` fora de códigos de tamanho fixo.
- **DATE com hora escondida.** `WHERE data_pedido = DATE '2025-01-08'` não encontra o pedido das 09:15 desse dia.
- **NUMBER sem precisão para dinheiro.** Aceita 0,333333... e espalha diferença de centavos nos totais. Defina a escala.
- **VARCHAR2 em bytes com texto acentuado.** O valor cabe na tela e estoura com ORA-12899 na gravação.
- **BINARY_DOUBLE para valores monetários.** 0,1 + 0,2 não dá exatamente 0,3 em ponto flutuante.

## Documentação oficial

- [SQL Language Reference — Data Types](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Data-Types.html)
- [SQL Language Reference — Data Type Comparison Rules](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Data-Type-Comparison-Rules.html)
