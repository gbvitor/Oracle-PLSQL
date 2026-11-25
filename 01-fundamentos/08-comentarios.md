# Comentários

## No código SQL e PL/SQL

| Forma | Alcance |
|---|---|
| `-- texto` | Do `--` até o fim da linha |
| `/* texto */` | Bloco, pode ocupar várias linhas; não pode ser aninhado |
| `/*+ hint */` | Não é comentário: é uma instrução para o otimizador (seção 11) |
| `REM texto` | Só no SQL*Plus/SQLcl, fora de comandos SQL; linha inteira |

```sql
-- Clientes ativos com limite definido
SELECT id_cliente,
       nome            -- razão social ou nome completo
  FROM clientes
 WHERE ativo = 'S'
   /* limite nulo = cliente ainda não analisado */
   AND limite_credito IS NOT NULL;
```

**Hint** tem forma de comentário, com um `+` logo depois de `/*`, e precisa vir imediatamente depois da palavra-chave do comando (`SELECT`, `UPDATE`, `INSERT`, `DELETE`, `MERGE`). Se houver erro de grafia, o Oracle o trata como comentário comum e ignora sem avisar.

```sql
SELECT /*+ INDEX(p ix_pedidos_data) */ * FROM pedidos p WHERE data_pedido >= DATE '2026-01-01';
```

## No dicionário de dados

Comentários também podem ser gravados **nos objetos**, para documentar a tabela e cada coluna dentro do próprio banco:

```sql
COMMENT ON TABLE  pedidos             IS 'Cabecalho do pedido de venda';
COMMENT ON COLUMN pedidos.id_vendedor IS 'Funcionario que fez a venda; nulo para venda pelo site';
```

Ficam em `USER_TAB_COMMENTS` e `USER_COL_COMMENTS`, aparecem nas ferramentas gráficas e são a documentação que acompanha a tabela para qualquer ambiente. O schema de exemplo usa esse recurso (`02-criar-schema.sql`).

## Armadilhas do SQL*Plus

O SQL*Plus não analisa SQL nem PL/SQL: ele olha as primeiras palavras de cada linha para decidir o que fazer com ela. Por isso, comentário no lugar errado muda o que é enviado ao banco. O guia do SQL*Plus recomenda:

- **Não colocar comentário depois do terminador** (`;` ou `/`) na mesma linha. Em `SELECT 'Y' FROM dual; -- teste`, o trecho depois do `;` pode ser lido como um comando novo e gerar SP2-0734. Ponha o comentário na linha de cima.
- **Não terminar linha de comentário com `;`** dentro de um comando: o SQL*Plus pode entender o `;` como fim do comando e enviá-lo pela metade.
- **Não usar `&` em comentários.** O `&` é tratado como variável de substituição mesmo dentro de comentário: `-- custo & margem` faz o SQL*Plus pedir um valor para `margem`. Em scripts que não usam substituição, `SET DEFINE OFF` desliga esse comportamento.

Os scripts deste repositório seguem essas regras: o resultado esperado de cada comando fica num comentário na linha de cima.

## O que comentar

O porquê, não o quê. `-- soma 1` em cima de `v := v + 1` não acrescenta nada; `-- o pedido 0 é reservado para ajuste manual, por isso começa em 1` acrescenta.

## Documentação oficial

- [SQL Language Reference — Comments](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Comments.html)
- [SQL Language Reference — COMMENT](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/COMMENT.html)
