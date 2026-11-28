# Variáveis de substituição: &, &&, DEFINE, UNDEFINE, ACCEPT, SET VERIFY

Variável de substituição é um recurso **do cliente** (SQL*Plus, SQLcl, SQL Developer): antes de mandar o comando ao banco, o cliente troca `&nome` pelo valor, como um localizar e substituir no texto. O banco nunca vê a variável, só o texto resultante.

## Comandos

| Forma | Faz |
|---|---|
| `&nome` | Usa o valor de `nome`; se não estiver definido, **pergunta** e esquece depois do comando |
| `&&nome` | Igual, mas se perguntar, **guarda** o valor para os próximos usos |
| `DEFINE nome = valor` | Define sem perguntar (sempre texto) |
| `DEFINE nome` / `DEFINE` | Mostra o valor de uma / de todas |
| `UNDEFINE nome` | Remove |
| `ACCEPT nome [NUMBER\|CHAR\|DATE] [DEFAULT valor] PROMPT 'texto' [HIDE]` | Pergunta com mensagem, tipo, valor padrão e entrada oculta (senha) |
| `COLUMN coluna NEW_VALUE nome` | Guarda em `nome` o valor da coluna da última linha de uma consulta |
| `&nome.` | O ponto encerra o nome: `&tabela._hist` vira `pedidos_hist` |

## Configurações

| SET | Efeito |
|---|---|
| `SET VERIFY OFF` | Não mostra as linhas `old` / `new` com o texto antes e depois da troca |
| `SET DEFINE OFF` | Desliga a substituição: `&` passa a ser um caractere comum |
| `SET DEFINE ^` | Troca o caractere de substituição |
| `SET CONCAT .` | Caractere que encerra o nome (padrão: ponto) |

## O `&` em textos

`INSERT INTO fornecedores (nome) VALUES ('Silva & Filhos')` faz o SQL*Plus perguntar o valor de `Filhos`. Duas saídas:

1. `SET DEFINE OFF` antes do comando (e `SET DEFINE ON` depois, se o script usar variáveis).
2. Montar o texto sem o caractere solto: `'Silva ' || CHR(38) || ' Filhos'`.

O mesmo acontece em **comentários** de scripts: `--` com `&` dentro também é examinado pelo SQL*Plus e pode gerar pergunta. Por isso a convenção deste repositório proíbe `&` em comentário de script.

## Substituição ou bind?

| | Substituição (`&x`) | Bind (`:x`, tópico 04) |
|---|---|---|
| Onde age | No cliente, antes de enviar | No banco, na execução |
| O banco vê | O valor no texto | O placeholder e o valor separados |
| Reaproveitamento do parse | Não: texto diferente a cada valor | Sim |
| Pode trocar nome de tabela, coluna, cláusula | Sim | Não |
| Uso típico | Parâmetros de script, nomes de objeto, trechos de comando | Valores em consultas repetidas |

## Documentação oficial

- [SQL*Plus User's Guide — Using Substitution Variables](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/using-substitution-variables-sqlplus.html)
- [SQL*Plus User's Guide — DEFINE, ACCEPT, SET DEFINE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/SQL-Plus-command-reference.html)
