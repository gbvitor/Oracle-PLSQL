# Escopo, blocos aninhados e propagação de exceções

## Escopo e visibilidade

Um bloco pode conter outros blocos (`DECLARE ... BEGIN ... END;` dentro do `BEGIN` ou do `EXCEPTION`). Cada um tem suas declarações:

- O que é declarado no bloco externo é visível nos internos.
- O que é declarado no interno não existe fora dele.
- Se o interno declarar um nome igual ao do externo, o interno **esconde** o externo. Para chegar ao externo, rotule o bloco e qualifique: `<<externo>> ... externo.v_total`.

Nomes repetidos entre blocos são permitidos, mas confundem. O caso perigoso é variável com o mesmo nome de coluna: dentro de uma instrução SQL, **a coluna vence**.

```sql
DECLARE
    id_cliente NUMBER := 5;
BEGIN
    DELETE FROM clientes WHERE id_cliente = id_cliente;
END;
```

O `WHERE` compara a coluna com ela mesma, é verdadeiro para toda linha não nula, e o comando tenta apagar a tabela inteira. Por isso a convenção de prefixos (`v_`, `p_`, `c_`) descrita em [CONVENCOES.md](../CONVENCOES.md).

## Como a exceção se propaga

1. O erro acontece numa instrução; o resto da seção executável daquele bloco é pulado.
2. Se o bloco tem um tratador que corresponde, ele roda e o bloco **termina normalmente**: o bloco de fora continua na instrução seguinte ao bloco interno.
3. Se não tem, o bloco termina com o erro, e o passo 2 se repete no bloco de fora.
4. Se nenhum bloco tratar, o erro chega ao cliente (SQL*Plus, aplicação).

Três casos que fogem da intuição:

| Onde o erro acontece | Quem pode tratar |
|---|---|
| Na seção `DECLARE` (inicialização de variável) | **Só o bloco de fora**. O tratador do próprio bloco ainda não está ativo. |
| Dentro de um tratador (`EXCEPTION`) | **Só o bloco de fora**. Os outros `WHEN` do mesmo bloco não pegam. |
| Exceção do usuário que sai do bloco onde foi declarada | Fora dele o nome não existe; só `WHEN OTHERS` pega (com SQLCODE 1). |

## Continuar um laço apesar do erro

O tratador do bloco que contém o laço encerra o laço. Para registrar o erro de uma linha e seguir para a próxima, o bloco com tratador vai **dentro** do laço:

```sql
FOR r IN c LOOP
    BEGIN
        processar(r);
    EXCEPTION
        WHEN OTHERS THEN
            registrar_erro(r.id, SQLERRM);
    END;
END LOOP;
```

## Exceção e transação

| Situação | O que acontece com o que a chamada alterou |
|---|---|
| Exceção tratada dentro do PL/SQL | **Nada é desfeito** automaticamente. O que foi feito antes do erro continua na transação, pendente de COMMIT ou ROLLBACK. |
| Exceção que chega ao cliente sem tratamento | O Oracle desfaz o que **aquela chamada** fez (volta a um savepoint implícito no início da chamada). O que a sessão fez antes dela, na mesma transação, continua pendente. |
| Subprograma que falha e o chamador trata | O que o subprograma alterou antes de falhar **não é desfeito**. O chamador decide (ROLLBACK TO SAVEPOINT, por exemplo). |

É a mesma atomicidade por comando da seção 06 (tópico 06), aplicada a uma chamada PL/SQL inteira: um bloco anônimo executado do SQL*Plus é uma chamada.

## Documentação oficial

- [PL/SQL Language Reference — Scope and Visibility of Identifiers](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-language-fundamentals.html)
- [PL/SQL Language Reference — Exception Propagation](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-error-handling.html)
