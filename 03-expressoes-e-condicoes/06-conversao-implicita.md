# Conversão implícita de tipos

## O que é

Quando uma expressão mistura tipos (texto com número, texto com data), o Oracle converte um deles **automaticamente**. Funciona na maior parte das vezes, e por isso passa despercebido até dar errado.

## Regras principais

| Situação | O que o Oracle faz |
|---|---|
| Coluna texto comparada com número (`documento = 123`) | Converte **a coluna** para número: `TO_NUMBER(documento) = 123` |
| Coluna número comparada com texto (`id_cliente = '1'`) | Converte **o texto** para número (seguro) |
| Coluna `DATE` comparada com texto (`data_pedido > '01/10/2026'`) | Converte o texto para data usando `NLS_DATE_FORMAT` da sessão |
| Número concatenado com texto | Converte o número com o formato padrão e o separador decimal da sessão |
| Texto em operação aritmética (`'10' + 5`) | Converte o texto para número |
| `INSERT` de texto em coluna `NUMBER` ou `DATE` | Converte usando as configurações NLS da sessão |

A regra geral para comparação entre texto e número é: **o texto é que vira número**. Quando o texto é a coluna, a conversão é aplicada em todas as linhas.

## Os três problemas

**1. O índice deixa de ser usado.** `WHERE documento = 10000000000101` vira `WHERE TO_NUMBER(documento) = ...`; o índice sobre `documento` não serve para isso.

**2. Erro que depende dos dados.** A mesma consulta quebra com ORA-01722 no dia em que entra um documento com letra, ou com ORA-01861/ORA-01843 quando a data em texto não bate com o formato.

**3. Resultado que depende da sessão.** `WHERE data_pedido >= '01/10/2026'` funciona numa ferramenta configurada com `DD/MM/YYYY` e falha (ou pior, interpreta dia e mês trocados) numa sessão com `NLS_DATE_FORMAT` diferente: outro cliente, outro servidor de aplicação, um job do banco.

## Como evitar

| Em vez de | Use |
|---|---|
| `documento = 10000000000101` | `documento = '10000000000101'` |
| `data_pedido >= '01/10/2026'` | `data_pedido >= DATE '2026-10-01'` ou `TO_DATE('01/10/2026', 'DD/MM/YYYY')` |
| `'Total: ' \|\| valor` | `'Total: ' \|\| TO_CHAR(valor, 'FM999G999G990D00')` |
| `TO_DATE(data_pedido)` sobre coluna que já é `DATE` | Nada: ela já é data. `TO_DATE` sobre `DATE` converte para texto e de volta, e pode cortar a hora |

Regra: compare sempre com o tipo da coluna, e faça toda conversão de forma **explícita**, com máscara de formato.

## Ver a conversão no plano

O plano de execução mostra a conversão no predicado (`filter(TO_NUMBER("DOCUMENTO")=10000000000101)`). Use `DBMS_XPLAN.DISPLAY` com `+PREDICATE` para conferir (seção 02, tópico 03).

## Documentação oficial

- [SQL Language Reference — Data Conversion](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Data-Type-Comparison-Rules.html)
