# Validação de CPF e CNPJ

## Cenário

Cadastro de clientes recebe CPF e CNPJ digitados, com ou sem máscara. Antes de gravar, é preciso conferir os dígitos verificadores; em consultas, listar os documentos inválidos; em testes, gerar documentos válidos.

## O cálculo (módulo 11)

Os dois documentos usam o mesmo esquema: cada posição é multiplicada por um peso, a soma é dividida por 11, e o dígito é `0` se o resto for menor que 2, senão `11 - resto`. O segundo dígito repete a conta incluindo o primeiro.

| | Base | Pesos do 1º dígito | Pesos do 2º dígito |
|---|---|---|---|
| CPF | 9 dígitos | 10 a 2 | 11 a 2 |
| CNPJ | 12 posições | 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2 | 6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2 |

Regras além da conta:

- **Todos os dígitos iguais** (`111.111.111-11`, `00.000.000/0000-00`) passam no cálculo, mas não são documentos válidos.
- **Tamanho e caracteres** são conferidos antes: 11 dígitos para CPF, 14 posições para CNPJ, depois de tirar a máscara.

## CNPJ alfanumérico (a partir de julho de 2026)

A Receita Federal passou a emitir CNPJ com letras nas 12 primeiras posições (`12.ABC.345/01DE-35`); os dois dígitos verificadores continuam numéricos e os CNPJs numéricos existentes continuam válidos. O cálculo é o mesmo módulo 11 com os mesmos pesos; muda só o valor de cada posição: **código ASCII menos 48**. Assim `0`–`9` valem 0–9 (o cálculo antigo continua igual) e `A`–`Z` valem 17–42.

Consequências para o banco:

- O documento é **texto** (`VARCHAR2(14)`), nunca `NUMBER`: número perde zero à esquerda e não aceita letra.
- Máscara por `TO_CHAR(n, '00G000G000...')` deixa de servir; formatar com `SUBSTR`.
- Validação por `REGEXP_LIKE(doc, '^[0-9]{14}$')` rejeita CNPJ novo. O padrão passa a ser `^[0-9A-Z]{12}[0-9]{2}$`.

## Onde validar

| Lugar | Observação |
|---|---|
| Na aplicação ou no pacote de API (seção 16) | Mensagem amigável antes de chegar ao banco |
| Trigger `BEFORE INSERT OR UPDATE` | Garante a regra para qualquer origem da gravação; aproveita para gravar sem máscara |
| Coluna virtual com a function | Precisa de function `DETERMINISTIC`; permite indexar e filtrar os inválidos |
| Constraint `CHECK` | **Não aceita** chamada a function do usuário; a regra do módulo 11 em SQL puro dentro do CHECK é possível, mas ilegível |

A function é usada em SQL com `DETERMINISTIC` e, em consultas grandes, `PRAGMA UDF` `[12c+]` (seção 09, tópico 02) para reduzir o custo da troca de contexto.

## Os documentos do schema de exemplo

Os CPFs e CNPJs de `clientes` são fictícios (`10000000000101`, `20000000001`...) e **todos falham** na validação. É de propósito: o schema não usa documento real. Para testar, o script gera documentos válidos a partir de uma base (`cpf_com_dv`, `cnpj_com_dv`).

## Documentação oficial

- [Receita Federal — CNPJ alfanumérico (perguntas e respostas)](https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/perguntas-e-respostas/cnpj/cnpj-alfanumerico.pdf)
- [PL/SQL Language Reference — DETERMINISTIC Clause](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/DETERMINISTIC-clause.html)
