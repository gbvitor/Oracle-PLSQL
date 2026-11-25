# DECODE

## Sintaxe

```sql
DECODE(expressao, busca1, resultado1 [, busca2, resultado2 ...] [, padrao])
```

Compara `expressao` com cada `busca`, em ordem, e devolve o `resultado` da primeira igual. Se nenhuma for igual, devolve `padrao`, ou NULL se ele não foi informado.

```sql
DECODE(tipo_pessoa, 'F', 'Pessoa fisica', 'J', 'Pessoa juridica', 'Nao informado')
```

É equivalente ao `CASE` simples, com duas diferenças que importam.

## Diferenças em relação ao CASE

| | `DECODE` | `CASE` |
|---|---|---|
| NULL igual a NULL | **Sim**: `DECODE(x, NULL, 'vazio')` funciona | Não, no `CASE` simples |
| Operadores | Só igualdade | Qualquer condição (`CASE` pesquisado) |
| Tipo do resultado | Definido pelo **primeiro** resultado; os outros são convertidos para ele | Todos precisam ser compatíveis, senão erro |
| PL/SQL | Só dentro de comando SQL | Também como expressão PL/SQL |
| Padrão SQL | Não (só Oracle) | Sim |

A comparação com NULL é o motivo mais comum para usar `DECODE` hoje. Exemplo clássico: comparar duas colunas considerando que dois NULLs são iguais.

```sql
WHERE DECODE(a.email, b.email, 0, 1) = 1   -- emails diferentes, tratando NULL = NULL
```

## Conversão pelo primeiro resultado

```sql
DECODE(status, 'ABERTO', 1, 'FATURADO', 2, 'outro')
```

O primeiro resultado é número, então `'outro'` precisa virar número: ORA-01722 quando o status não é ABERTO nem FATURADO. O inverso também surpreende: se o primeiro resultado é texto, os números viram texto, e a ordenação do resultado passa a ser alfabética (`'10'` antes de `'2'`).

## Quando usar

- Ler código existente: `DECODE` é muito comum em sistemas Oracle antigos.
- Comparação com tratamento de NULL, de forma curta.
- Em código novo, prefira `CASE`: é padrão, mais legível e funciona em PL/SQL.

Padrão legado que ainda aparece: `DECODE(SIGN(a - b), 1, 'maior', -1, 'menor', 'igual')`, usado antes de existir o `CASE` para comparar com `>` e `<`.

## Documentação oficial

- [SQL Language Reference — DECODE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/DECODE.html)
