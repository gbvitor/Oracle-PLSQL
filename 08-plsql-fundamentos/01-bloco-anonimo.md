# Bloco anônimo e DBMS_OUTPUT

## Estrutura de um bloco

```sql
DECLARE
    -- declarações: variáveis, constantes, cursores, tipos, exceções (opcional)
BEGIN
    -- comandos (obrigatório: pelo menos um)
EXCEPTION
    -- tratamento de erros (opcional)
END;
/
```

- Só `BEGIN ... END;` é obrigatório. Sem nada para fazer, o corpo precisa ao menos de `NULL;`.
- **Bloco anônimo** não tem nome e não fica guardado no banco: é enviado, executado e descartado. Procedures, functions, packages e triggers são blocos com nome, guardados e compilados (seção 09).
- Blocos podem ser **aninhados**: um `BEGIN ... END;` dentro de outro, com suas próprias declarações e tratamento de erro (tópico 11).

## A barra no SQL*Plus e no SQLcl

Dentro de um bloco há vários `;`, por isso o cliente não sabe onde o bloco termina. A linha com **só `/`** encerra e executa. Esquecer a barra deixa o SQL*Plus esperando mais linhas; colocar uma barra a mais depois de um comando SQL **executa o comando de novo**.

## DBMS_OUTPUT

`DBMS_OUTPUT.PUT_LINE(texto)` escreve num buffer da sessão. O cliente só mostra esse buffer se a saída estiver ligada, e só **depois que o bloco termina**:

```sql
-- SQL*Plus / SQLcl
SET SERVEROUTPUT ON
SET SERVEROUTPUT ON SIZE UNLIMITED
```

Em ferramentas gráficas, há uma aba ou opção própria (no SQL Developer, "Dbms Output"; no DataGrip, o botão de saída do servidor).

| Chamada | Efeito |
|---|---|
| `PUT_LINE(texto)` | Escreve e quebra a linha |
| `PUT(texto)` | Escreve sem quebrar |
| `NEW_LINE` | Quebra a linha |
| `ENABLE` / `DISABLE` | Liga e desliga o buffer pelo código |

Limitações:

- **Não é log.** A saída aparece só no fim e só para quem executou; um processo agendado ou uma aplicação não vê nada. Para registrar execução, grave numa tabela de log (seção 09, transação autônoma).
- Não aceita `BOOLEAN` diretamente antes do 23ai: converta com `CASE WHEN v THEN 'TRUE' ELSE 'FALSE' END`.
- Cada linha aceita até 32767 bytes.

## Documentação oficial

- [PL/SQL Language Reference — Blocks](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/block.html)
- [PL/SQL Packages and Types Reference — DBMS_OUTPUT](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_OUTPUT.html)
