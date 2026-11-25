# DUAL e consultas sem tabela

## O que é

`DUAL` é uma tabela do dicionário de dados, pertencente ao `SYS` e acessível a todos, com **uma coluna** (`DUMMY`, valor `'X'`) e **uma linha**. Existe para que se possa escrever um `SELECT` que não lê nenhuma tabela: no Oracle, até o 19c, todo `SELECT` precisa de `FROM`.

```sql
SELECT SYSDATE FROM dual;
SELECT 2 * 3.5 AS resultado FROM dual;
SELECT UPPER('oracle') FROM dual;
```

Como tem exatamente uma linha, a expressão é avaliada uma vez e volta um resultado. Quando a consulta não usa a coluna `DUMMY`, o otimizador nem lê a tabela (operação "FAST DUAL" no plano de execução).

## Usos comuns

- Testar uma função ou expressão antes de colocá-la numa consulta.
- Ler o valor de uma sequence: `SELECT minha_seq.NEXTVAL FROM dual`.
- Ler contexto da sessão: `SELECT USER, SYS_CONTEXT('USERENV', 'CON_NAME') FROM dual`.
- Gerar linhas com `CONNECT BY LEVEL` (tópico 06).
- Montar uma lista de valores fixos com `UNION ALL`, para usar como tabela dentro de outra consulta.

## Sem FROM `[23ai+]`

A partir do 23ai, o `FROM dual` é opcional: `SELECT SYSDATE;` é válido. Em código que precisa rodar no 19c, mantenha o `FROM dual`.

## Em PL/SQL

Dentro de PL/SQL, não é necessário `SELECT ... FROM dual` para calcular expressões: `v_hoje := SYSDATE;` é direto e não passa pelo motor SQL. Usar `SELECT ... INTO ... FROM dual` só para atribuir valor é um custo desnecessário (troca de contexto entre PL/SQL e SQL).

## Armadilhas

- **Mais de uma linha em DUAL.** Se alguém, com privilégio de SYS, inserir linhas em `DUAL`, toda consulta que depende dela passa a devolver resultados repetidos. Nunca altere essa tabela.
- **Objeto próprio chamado DUAL.** Um objeto local chamado `dual` tem precedência sobre o synonym público. Não crie objetos com esse nome.

## Documentação oficial

- [SQL Language Reference — Selecting from the DUAL Table](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Selecting-from-the-DUAL-Table.html)
