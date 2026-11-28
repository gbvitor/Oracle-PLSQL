# Executar scripts: @, @@, START e parâmetros posicionais

## Os comandos

| Comando | Procura o arquivo em |
|---|---|
| `@arquivo` / `START arquivo` | Diretório atual do SQL*Plus, depois as pastas de `SQLPATH` (Windows) / `ORACLE_PATH` (Linux) |
| `@@arquivo` | O **mesmo diretório do script que está chamando** |
| `sqlplus usuario@conexao @arquivo` | Executa ao abrir; útil em agendador e pipeline |

- Extensão `.sql` é assumida se omitida: `@relatorio` roda `relatorio.sql`.
- Script chamado por outro com `@@` é a forma de montar um **script mestre** (instalação, deploy) que funciona de qualquer diretório: o mestre chama `@@01-tabelas.sql`, `@@02-dados.sql`... É o que `00-ambiente/instalar.sql` faz.
- Um script termina no fim do arquivo. Para encerrar o SQL*Plus ao final (agendador), o script precisa ter `EXIT`; sem ele, o SQL*Plus fica esperando comandos.

## Parâmetros posicionais

```text
@relatorio-cliente.sql 3 'Belo Horizonte'
```

Dentro do script, os valores chegam como `&1`, `&2`, ... (variáveis de substituição, tópico 03):

```sql
SELECT nome FROM clientes WHERE id_cliente = &1;
SELECT nome FROM clientes WHERE cidade = '&2';
```

- A substituição é **textual**, feita antes de o comando ir ao banco: `&1` vira `3` no texto. Texto precisa de aspas no script (`'&2'`).
- Valor com espaço é passado entre aspas na chamada.
- Parâmetro não informado faz o SQL*Plus **perguntar** o valor (`Enter value for 1:`). Em execução automática, isso trava o processo; o script deve validar os parâmetros ou definir padrões.
- Depois de usado, `&1` fica definido até `UNDEFINE 1` ou o fim da sessão, inclusive para o próximo script.

## Boa prática para scripts com parâmetros

1. Copiar cada parâmetro para um nome legível logo no início: `DEFINE p_id_cliente = &1`.
2. `SET VERIFY OFF` para não poluir a saída com as linhas `old`/`new` da substituição.
3. Documentar no cabeçalho os parâmetros esperados e um exemplo de chamada.
4. Em automação, `WHENEVER SQLERROR EXIT FAILURE` (tópico 07) e `EXIT` no fim.

## Documentação oficial

- [SQL*Plus User's Guide — Running Scripts](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/using-scripts-in-SQL-Plus.html)
- [SQL*Plus User's Guide — @ ("at" sign) e @@ (double "at" sign)](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqpug/SQL-Plus-command-reference.html)
