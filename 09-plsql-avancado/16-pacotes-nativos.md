# Pacotes nativos úteis

O Oracle traz centenas de packages prontas (`DBMS_*`, `UTL_*`). Estas são as que mais aparecem em código PL/SQL do dia a dia. Referência completa: *PL/SQL Packages and Types Reference*.

## DBMS_OUTPUT

| Rotina | Faz |
|---|---|
| `PUT_LINE(texto)` | Escreve uma linha no buffer |
| `PUT(texto)` + `NEW_LINE` | Monta a linha em partes |
| `ENABLE(tamanho)` / `DISABLE` | Liga e desliga o buffer (`SET SERVEROUTPUT ON` chama o ENABLE) |
| `GET_LINE`, `GET_LINES` | Lê o buffer: é o que o SQL*Plus faz depois de cada chamada |

Lembretes (seção 08, tópico 01): a saída só aparece no fim da chamada, só para a sessão que executou, e não serve como log. Linha com mais de 32767 bytes dá erro.

## Pausa: DBMS_SESSION.SLEEP

`DBMS_SESSION.SLEEP(segundos)` `[18c+]` é executável por qualquer usuário. Antes dela, a pausa era `DBMS_LOCK.SLEEP`, que exige grant de `EXECUTE ON DBMS_LOCK` dado pelo DBA. Código antigo ainda usa a segunda.

## DBMS_APPLICATION_INFO

Marca a sessão com **módulo** e **ação**, visíveis em `V$SESSION` (colunas `MODULE`, `ACTION`, `CLIENT_INFO`), nos relatórios AWR e no Enterprise Manager. Num processo longo, mostra ao DBA o que a sessão está fazendo.

```sql
DBMS_APPLICATION_INFO.SET_MODULE(module_name => 'carga_pedidos', action_name => 'lendo arquivo');
DBMS_APPLICATION_INFO.SET_ACTION('gravando lote 12');
```

`SET_SESSION_LONGOPS` publica progresso em `V$SESSION_LONGOPS` (percentual e tempo restante estimado).

## DBMS_LOB

Para `CLOB` e `BLOB` maiores que 32767 bytes (o limite de `VARCHAR2` em PL/SQL):

| Rotina | Faz |
|---|---|
| `CREATETEMPORARY` / `FREETEMPORARY` | Cria e libera um LOB temporário |
| `APPEND`, `WRITEAPPEND` | Acrescenta no fim |
| `GETLENGTH` | Tamanho (em caracteres para CLOB) |
| `SUBSTR`, `INSTR` | Versões de LOB das funções de texto (argumentos em outra ordem: `SUBSTR(lob, qtd, posicao)`) |
| `COPY`, `ERASE`, `TRIM` | Edição |

Concatenar com `||` num CLOB funciona, mas cada concatenação cria uma cópia; para montar um arquivo grande, acumule em `VARCHAR2(32767)` e descarregue com `WRITEAPPEND` quando encher.

## UTL_FILE

Lê e grava arquivos de texto **no servidor do banco** (não na máquina de quem executa). Exige um objeto `DIRECTORY`, criado pelo DBA, apontando para uma pasta do servidor, e grant de `READ`/`WRITE` nele.

```sql
v_arq := UTL_FILE.FOPEN('TMP_DIR', 'pedidos.csv', 'w', 32767);
UTL_FILE.PUT_LINE(v_arq, 'id;status;valor');
UTL_FILE.FCLOSE(v_arq);
```

- Modos: `r` (leitura), `w` (grava do zero), `a` (acrescenta).
- Sempre `FCLOSE` também no tratador de exceção (`FCLOSE_ALL` em último caso).
- Em banco autônomo e em muitos ambientes gerenciados, o acesso a disco é restrito; o caminho é gravar em LOB e exportar por outro meio (`DBMS_CLOUD`, aplicação).

## Outras que vale conhecer

| Package | Para |
|---|---|
| `DBMS_RANDOM` | Valores e textos aleatórios (`VALUE`, `STRING`), com `SEED` para repetir a sequência. Não é criptográfico |
| `DBMS_UTILITY` | `GET_TIME` (centésimos de segundo, para medir trechos), `FORMAT_ERROR_BACKTRACE` (tópico 13), `COMPILE_SCHEMA` (tópico 15) |
| `DBMS_METADATA` | DDL de qualquer objeto (`GET_DDL`), seção 07 |
| `DBMS_SCHEDULER` | Jobs agendados, seção 13 |
| `DBMS_STATS` | Estatísticas do otimizador, seção 11 |
| `DBMS_XPLAN` | Plano de execução, seção 11 |
| `UTL_MATCH` | Similaridade de texto (Levenshtein, Jaro-Winkler) |
| `DBMS_CRYPTO` | Hash e criptografia (exige grant do DBA) |
| `UTL_HTTP`, `APEX_WEB_SERVICE` | Chamadas HTTP (exigem ACL de rede configurada pelo DBA) |

## Documentação oficial

- [PL/SQL Packages and Types Reference](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/index.html)
- [DBMS_SESSION.SLEEP](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_SESSION.html)
- [DBMS_APPLICATION_INFO](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_APPLICATION_INFO.html)
- [DBMS_LOB](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_LOB.html)
- [UTL_FILE](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/UTL_FILE.html)
