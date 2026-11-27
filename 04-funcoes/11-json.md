# JSON

## Onde o JSON fica

| Versão | Armazenamento |
|---|---|
| 12c a 19c | Texto: `VARCHAR2`, `CLOB` ou `BLOB`, com a constraint `CHECK (coluna IS JSON)` para garantir que o conteúdo é JSON válido |
| `[21c+]` | Tipo nativo `JSON`, em formato binário (OSON), mais rápido para consultar |

A constraint `IS JSON` também habilita a **notação de ponto**: `SELECT t.doc.cliente.nome FROM tabela t` (o alias da tabela é obrigatório).

## Ler JSON

| Função | Devolve | Exemplo |
|---|---|---|
| `JSON_VALUE(doc, '$.caminho')` | Um valor escalar (texto, número, data) | `JSON_VALUE(doc, '$.cliente.uf')` |
| `JSON_QUERY(doc, '$.caminho')` | Um objeto ou array, como texto JSON | `JSON_QUERY(doc, '$.itens')` |
| `JSON_EXISTS(doc, '$.caminho')` | Condição: o caminho existe | `WHERE JSON_EXISTS(doc, '$.desconto')` |
| `JSON_TABLE(doc, '$' COLUMNS (...))` | Linhas e colunas a partir do JSON | Arrays viram linhas com `NESTED PATH` |

Caminhos: `$` é a raiz, `.campo` entra num objeto, `[0]` pega um elemento do array (começa em 0), `[*]` todos.

`JSON_VALUE` aceita `RETURNING NUMBER`, `RETURNING DATE` etc., e cláusulas para caminho inexistente ou erro: `DEFAULT 0 ON EMPTY`, `NULL ON ERROR` (padrão), `ERROR ON ERROR`.

## Gerar JSON

| Função | Gera |
|---|---|
| `JSON_OBJECT('chave' VALUE expr, ...)` | Um objeto por linha |
| `JSON_ARRAY(expr, ...)` | Um array por linha |
| `JSON_OBJECTAGG(chave VALUE valor)` | Um objeto agregando várias linhas |
| `JSON_ARRAYAGG(expr ORDER BY ...)` | Um array agregando várias linhas |

Detalhes que mudam o resultado:

- `JSON_OBJECT` mantém chaves com valor nulo (`NULL ON NULL`, padrão); `ABSENT ON NULL` as omite. Em `JSON_ARRAY`/`JSON_ARRAYAGG`, o padrão é o contrário: `ABSENT ON NULL`.
- O resultado padrão é `VARCHAR2(4000)`. Documentos maiores precisam de `RETURNING CLOB`, senão dão erro.
- Para incluir um JSON pronto (de outra função ou coluna) sem que ele vire texto escapado, use `FORMAT JSON` ou gere-o com outra função JSON diretamente.
- `NUMBER` vira número JSON sem zeros à direita (`29.90` vira `29.9`); `DATE` vira texto no formato ISO.

`JSON_SERIALIZE(doc PRETTY)` `[19c+]` formata para leitura.

## Armadilhas

- **`JSON_VALUE` em objeto ou array** devolve NULL (por causa do `NULL ON ERROR` padrão) em vez de dar erro. Use `JSON_QUERY` para estruturas, ou `ERROR ON ERROR` para descobrir o problema.
- **Caminho com maiúsculas e minúsculas**: `$.Cliente` e `$.cliente` são caminhos diferentes.
- **Documento grande truncado ou com erro** por causa do `VARCHAR2(4000)` padrão.

## Documentação oficial

- [JSON Developer's Guide 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/adjsn/index.html)
