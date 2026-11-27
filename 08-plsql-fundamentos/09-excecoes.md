# Exceções: predefinidas, do usuário e PRAGMA EXCEPTION_INIT

Quando um erro acontece no corpo do bloco, a execução para na instrução que falhou e salta para a seção `EXCEPTION`. Se algum `WHEN` corresponder ao erro, o tratador roda e o bloco termina normalmente; se nenhum corresponder, o erro sobe para o bloco de fora (tópico 11).

```sql
BEGIN
    ...
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ...
    WHEN TOO_MANY_ROWS OR VALUE_ERROR THEN
        ...
    WHEN OTHERS THEN
        ...
        RAISE;
END;
```

- Cada exceção pode aparecer em um só `WHEN` do mesmo bloco; `OR` junta várias num tratador.
- `WHEN OTHERS` pega tudo o que não foi tratado antes e precisa ser o último.
- Depois que o tratador roda, **não há volta** para a instrução seguinte à que falhou. Para continuar um laço depois de um erro, coloque um bloco aninhado dentro do laço (tópico 11).

## Três tipos de exceção

| Tipo | Tem nome? | Tem código ORA? | Como surge |
|---|---|---|---|
| Predefinida | Sim, no package `STANDARD` | Sim | O Oracle levanta sozinho |
| Erro interno sem nome | Não | Sim | O Oracle levanta; você dá nome com `PRAGMA EXCEPTION_INIT` ou pega com `OTHERS` |
| Do usuário | Sim, declarado por você | Não (SQLCODE = 1) | Você levanta com `RAISE` |

## Predefinidas mais comuns

| Nome | ORA | Quando |
|---|---|---|
| `NO_DATA_FOUND` | 01403 (SQLCODE 100) | `SELECT INTO` sem linha; leitura de elemento inexistente em associative array |
| `TOO_MANY_ROWS` | 01422 | `SELECT INTO` com mais de uma linha |
| `ZERO_DIVIDE` | 01476 | Divisão por zero |
| `VALUE_ERROR` | 06502 | Conversão, truncamento ou restrição de tamanho **em PL/SQL** |
| `INVALID_NUMBER` | 01722 | Conversão de texto em número **dentro de uma instrução SQL** |
| `DUP_VAL_ON_INDEX` | 00001 | Chave primária ou única duplicada |
| `CASE_NOT_FOUND` | 06592 | `CASE` de comando sem `ELSE` e sem correspondência |
| `CURSOR_ALREADY_OPEN` | 06511 | `OPEN` em cursor já aberto |
| `INVALID_CURSOR` | 01001 | `FETCH` ou `CLOSE` em cursor fechado |
| `ROWTYPE_MISMATCH` | 06504 | Cursor variável com estrutura diferente da variável de destino |
| `TIMEOUT_ON_RESOURCE` | 00051 | Tempo esgotado esperando um recurso |

`TO_NUMBER('abc')` é o exemplo clássico da diferença entre as duas de conversão: numa atribuição PL/SQL dá `VALUE_ERROR`; dentro de um `SELECT ... INTO` dá `INVALID_NUMBER`.

## Exceção do usuário

```sql
DECLARE
    e_limite_excedido EXCEPTION;
BEGIN
    IF v_total > v_limite THEN
        RAISE e_limite_excedido;
    END IF;
EXCEPTION
    WHEN e_limite_excedido THEN
        ...
END;
```

Serve para regra de negócio que só faz sentido dentro do próprio código. Se o erro precisa chegar ao chamador com mensagem e código próprios (uma aplicação, outro sistema), use `RAISE_APPLICATION_ERROR` (tópico 10).

## PRAGMA EXCEPTION_INIT

Dá nome a um erro ORA que não tem nome predefinido, para tratar por nome em vez de testar `SQLCODE` dentro do `OTHERS`:

```sql
DECLARE
    e_registro_filho EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_registro_filho, -2292);
BEGIN
    DELETE FROM clientes WHERE id_cliente = :id;
EXCEPTION
    WHEN e_registro_filho THEN
        ...
END;
```

O código vai **negativo** (exceto 100, que é o NO_DATA_FOUND). Erros que costumam ganhar nome assim:

| Código | Erro |
|---|---|
| -1400 | Inserir NULL em coluna NOT NULL |
| -2290 | Violação de CHECK |
| -2291 | Chave pai não encontrada (FK) |
| -2292 | Registro filho encontrado (FK) |
| -54 | Recurso ocupado com NOWAIT |
| -20001 a -20999 | Erros da própria aplicação (tópico 10) |

Em código grande, declare essas exceções uma vez numa package de exceções e reutilize (seção 09, tópico 03).

## WHEN OTHERS THEN NULL

Engolir o erro faz o programa terminar como se tudo tivesse dado certo. O dado fica pela metade e ninguém sabe por quê. `WHEN OTHERS` é aceitável quando registra o erro e termina em `RAISE` ou `RAISE_APPLICATION_ERROR`; o compilador avisa (PLW-06009) em unidades armazenadas quando o `OTHERS` não termina assim, se os avisos estiverem ligados com `ALTER SESSION SET PLSQL_WARNINGS = 'ENABLE:ALL'`.

## Documentação oficial

- [PL/SQL Language Reference — PL/SQL Error Handling](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-error-handling.html)
- [PL/SQL Language Reference — EXCEPTION_INIT Pragma](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/EXCEPTION_INIT-pragma.html)
