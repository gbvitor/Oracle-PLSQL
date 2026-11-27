# Procedures: parâmetros, modos, valores padrão e notação

Procedure é um bloco PL/SQL com nome, compilado e guardado no banco. Executa uma ação; não devolve valor (para isso, function, tópico 02), mas pode devolver resultados por parâmetros `OUT`.

```sql
CREATE OR REPLACE PROCEDURE reajustar_categoria (
    p_id_categoria IN  produtos.id_categoria%TYPE,
    p_pct          IN  NUMBER DEFAULT 5,
    p_qtd          OUT PLS_INTEGER
) IS
    v_fator NUMBER;
BEGIN
    v_fator := 1 + p_pct / 100;
    UPDATE produtos
       SET preco_unitario = ROUND(preco_unitario * v_fator, 2)
     WHERE id_categoria = p_id_categoria;
    p_qtd := SQL%ROWCOUNT;
END reajustar_categoria;
/
```

- `IS` e `AS` são equivalentes. Não há `DECLARE`: as declarações ficam entre `IS` e `BEGIN`.
- `CREATE OR REPLACE` recompila mantendo os grants dados sobre a procedure.
- Erro de compilação não impede a criação: o objeto fica **INVALID**. No SQL*Plus, `SHOW ERRORS` mostra as mensagens; em qualquer cliente, `USER_ERRORS`.
- Tipo de parâmetro **sem tamanho**: `VARCHAR2`, não `VARCHAR2(20)`. `%TYPE` traz o tipo da coluna e evita o problema.

## Modos de parâmetro

| Modo | Dentro da procedure | Na chamada | Passagem |
|---|---|---|---|
| `IN` (padrão) | Só leitura (atribuir dá PLS-00363) | Valor, expressão ou variável | Por referência |
| `OUT` | Começa **NULL**, mesmo que a variável do chamador tenha valor | Variável | Por valor: copiado de volta no fim |
| `IN OUT` | Lê o valor recebido e pode alterar | Variável | Por valor: copiado na entrada e na saída |

Se a procedure termina com **exceção não tratada**, os parâmetros `OUT` e `IN OUT` do chamador ficam com o valor que tinham antes da chamada: a cópia de volta não acontece.

## NOCOPY

`p_lista IN OUT NOCOPY t_lista` pede passagem por referência para `OUT` e `IN OUT`. Evita copiar coleções e LOBs grandes duas vezes. Consequências:

- É um **pedido**: o compilador pode ignorar (por exemplo, quando há conversão de tipo).
- Com exceção não tratada, o chamador pode ver o parâmetro **parcialmente alterado**, porque não houve cópia.
- Para escalares (NUMBER, DATE, VARCHAR2 curto), o ganho é desprezível.

## Valores padrão e notação

```sql
-- posicional
reajustar_categoria(5, 10, v_qtd);

-- nomeada, usa o DEFAULT de p_pct
reajustar_categoria(p_id_categoria => 5, p_qtd => v_qtd);

-- mista: posicionais primeiro
reajustar_categoria(5, p_qtd => v_qtd);
```

- Só `IN` aceita `DEFAULT`.
- Notação nomeada deixa a chamada legível e sobrevive a parâmetro novo com `DEFAULT` acrescentado no meio da lista.
- Parâmetro novo sempre com `DEFAULT`, para não quebrar quem já chama.

## Chamando do SQL*Plus

```sql
VARIABLE qtd NUMBER
EXEC reajustar_categoria(5, 10, :qtd)
PRINT qtd
```

`EXEC` é atalho do SQL*Plus para `BEGIN ... END;`.

## Procedure local

Procedure declarada dentro de outro bloco (como nos scripts da seção 08) existe só ali. Bom para organizar um bloco anônimo ou o corpo de uma package sem publicar a rotina.

## Transação

A procedure **não faz COMMIT sozinha**. Quem chama decide. Procedure que faz COMMIT por dentro impede o chamador de juntar várias operações numa transação; deixe o COMMIT para a camada que conhece o processo inteiro (job, tela, script de carga).

## Documentação oficial

- [PL/SQL Language Reference — CREATE PROCEDURE Statement](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/CREATE-PROCEDURE-statement.html)
- [PL/SQL Language Reference — Subprogram Parameters](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-subprograms.html)
