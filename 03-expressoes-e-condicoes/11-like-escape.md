# LIKE e ESCAPE

## Sintaxe

```sql
texto [NOT] LIKE padrao [ESCAPE 'caractere']
```

| Curinga | Significa | Exemplo | Encontra |
|---|---|---|---|
| `%` | Zero ou mais caracteres quaisquer | `'Papel%'` | "Papel A4", "Papelaria" |
| `_` | Exatamente um caractere | `'_ana'` | "Ana" não (3 letras); "Rana", "Lana" |

Sem curinga, `LIKE` funciona como `=`.

## ESCAPE

Para procurar `%` ou `_` como caractere literal, escolha um caractere de escape e coloque-o antes:

```sql
WHERE descricao LIKE '%50\%%' ESCAPE '\'    -- contém "50%"
WHERE email     LIKE '%\_%'   ESCAPE '\'    -- contém "_"
```

Sem o escape, `'%_%'` encontra qualquer texto com pelo menos um caractere.

## Regras e comportamento

- **Diferencia maiúsculas e minúsculas.** `'papel%'` não encontra "Papel A4". Para ignorar: `UPPER(nome) LIKE 'PAPEL%'` (impede o índice comum) ou sessão com `NLS_COMP = LINGUISTIC` e `NLS_SORT = BINARY_CI`.
- **NULL**: `NULL LIKE '%'` é UNKNOWN. `LIKE '%'` não devolve as linhas com coluna nula.
- **Número ou data com LIKE** passa por conversão implícita para texto (`id_cliente LIKE '1%'`). Funciona, mas depende do formato e impede o índice.

## Índice

| Padrão | Busca por faixa no índice? |
|---|---|
| `'Papel%'` (prefixo fixo) | Sim (`INDEX RANGE SCAN`) |
| `'%Ltda'` (começa com `%`) | Não: todo valor precisa ser examinado (leitura completa da tabela ou do índice) |
| `'%Bem%'` | Não |

Para busca por sufixo, um índice baseado em função sobre `REVERSE(coluna)` com `LIKE REVERSE(...)` é o truque clássico. Para busca textual de verdade, Oracle Text (`CONTAINS`).

## Documentação oficial

- [SQL Language Reference — Pattern-matching Conditions](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Pattern-matching-Conditions.html)
