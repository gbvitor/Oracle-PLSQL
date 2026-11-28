# DESCRIBE, SHOW ERRORS, SHOW PARAMETER e outros SHOW

## DESCRIBE

`DESC objeto` mostra a estrutura sem precisar consultar o dicionário:

| Objeto | Mostra |
|---|---|
| Tabela, view, sinônimo | Colunas, `NOT NULL` e tipo |
| Procedure, function | Parâmetros: nome, tipo, modo (`IN`/`OUT`), se tem `DEFAULT`; o tipo do retorno |
| Package | Cada rotina pública com seus parâmetros |
| Tipo de objeto | Atributos e métodos |

`DESC dono.objeto` para outro schema; `DESC objeto@dblink` para um banco remoto. Para filtrar, ordenar ou juntar com outra informação, a consulta ao dicionário da seção 10 (tópico 02, passo 3) faz o mesmo em forma de tabela.

## SHOW

| Comando | Mostra |
|---|---|
| `SHOW ERRORS` | Erros da última unidade PL/SQL compilada nesta sessão |
| `SHOW ERRORS PROCEDURE nome` (ou `FUNCTION`, `PACKAGE`, `PACKAGE BODY`, `TRIGGER`, `VIEW`, `TYPE`) | Erros de uma unidade específica |
| `SHOW USER` | Usuário conectado |
| `SHOW CON_NAME` `[12c+]` | Container atual |
| `SHOW PARAMETER texto` | Parâmetros de inicialização cujo nome contém o texto (exige leitura de `V$PARAMETER`) |
| `SHOW SPPARAMETER texto` | O mesmo, como está no spfile (valor de partida da próxima inicialização) |
| `SHOW SGA` | Tamanho das áreas de memória (privilégio de DBA) |
| `SHOW RECYCLEBIN` | Objetos excluídos que ainda podem voltar com `FLASHBACK TABLE ... TO BEFORE DROP` |
| `SHOW RELEASE` | Versão do cliente SQL*Plus |
| `SHOW ALL` | Todas as configurações `SET` em vigor |
| `SHOW nome_do_set` | Uma configuração: `SHOW LINESIZE`, `SHOW AUTOCOMMIT` |

`SHOW ERRORS` sem argumento é o hábito certo logo depois de cada `CREATE OR REPLACE` de PL/SQL num script. A forma com tipo e nome funciona a qualquer momento, inclusive para unidades compiladas por outro script; é a mesma informação de `USER_ERRORS`.

## Documentação oficial

- [SQL*Plus User's Guide — DESCRIBE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/DESCRIBE.html)
- [SQL*Plus User's Guide — SHOW](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/SHOW.html)
