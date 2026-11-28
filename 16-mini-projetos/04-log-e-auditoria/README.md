# 04 — Log e auditoria genéricos

## Enunciado

Duas peças reutilizáveis por qualquer sistema do schema:

- **Log de execução** (`log_pkg`): níveis (DEBUG, INFO, AVISO, ERRO), agrupamento por execução com início, fim e situação, erro gravado com pilha, backtrace e pilha de chamadas, módulo da sessão visível em `V$SESSION`, expurgo por idade. O log tem de ficar gravado **mesmo quando o processo faz ROLLBACK**.
- **Auditoria de alterações** (`log_pkg_auditoria`): gerar, a partir do dicionário de dados, o trigger que grava cada coluna alterada (valor antigo e novo) de qualquer tabela com chave primária. A auditoria tem de **sumir junto** com uma alteração desfeita.

## Modelo

| Tabela | Conteúdo |
|---|---|
| `log_execucoes` | Uma linha por execução: módulo, início, fim, situação (`EXECUTANDO`, `OK`, `ERRO`), usuário, SID |
| `log_eventos` | Eventos: momento, nível, execução, módulo, mensagem, detalhe (CLOB com pilha e backtrace) |
| `log_aud_alteracoes` | Uma linha por coluna alterada: tabela, chave, operação (I/U/D), coluna, valor antigo, valor novo, usuário, execução |
| `log_demo_contas` | Tabela de demonstração e de teste da auditoria |

## Decisões de projeto

| Decisão | Por quê |
|---|---|
| Log em **transação autônoma**; auditoria **na mesma transação** | São perguntas diferentes. O log responde "o que o processo tentou e onde falhou", e o registro do erro é justamente o que não pode sumir no ROLLBACK. A auditoria responde "o que mudou nos dados", e uma alteração desfeita não mudou nada (testes T05 e T17) |
| Falha ao gravar o log **não derruba** o processo | O log é acessório: um tablespace cheio no log não deve parar o faturamento. O preço é que a falha só aparece no `DBMS_OUTPUT`. A decisão contrária (propagar) é defensável quando o log é exigência legal |
| `erro` lê `FORMAT_ERROR_STACK` e `FORMAT_ERROR_BACKTRACE` **antes** de qualquer outra chamada | O backtrace aponta a linha onde o erro nasceu, que é o que se quer depois (seção 09, tópico 13). Ler depois de outra operação que trate um erro trocaria a informação |
| Nível mínimo em **variável de package** | Cada sessão tem a sua cópia: dá para ligar DEBUG numa sessão de diagnóstico sem afetar as outras |
| **`DBMS_APPLICATION_INFO.SET_MODULE`** na abertura da execução | O DBA vê em `V$SESSION` (e nos relatórios de desempenho) qual processo está rodando em cada sessão (seção 13, tópico 06) |
| Trigger **gerado** do dicionário, não escrito à mão | Uma regra só para todas as tabelas; coluna nova na tabela entra gerando de novo. O texto pode ser revisado antes com `texto_trigger` |
| Valores gravados como texto **independente da sessão** | Número com `TO_CHAR(x, 'TM9', 'NLS_NUMERIC_CHARACTERS=''.,''')` e data em ISO: a auditoria lida em outra sessão, com outro NLS, mostra o mesmo valor |
| Só grava coluna que **mudou**, com `DECODE` | `UPDATE ... SET saldo = saldo` não gera ruído; troca de valor por NULL é detectada (testes T14 e T15) |
| Nome da tabela validado com **`DBMS_ASSERT`** e contra `USER_TABLES` | O nome vai concatenado num DDL dinâmico: sem validação, é injeção de SQL (teste T10) |
| `gerar_trigger` em **transação autônoma** | DDL faz `COMMIT` implícito. Dentro da transação de quem chamou, confirmaria sem aviso o trabalho pendente dele. Na autônoma, o `COMMIT` é só da DDL (teste T18) |

## Privilégio direto

`gerar_trigger` executa `CREATE TRIGGER` por SQL dinâmico dentro de uma package de direitos do dono. Privilégio recebido por **role** não vale ali: o usuário precisa de `CREATE TRIGGER` concedido diretamente (o usuário `estudo` de `00-ambiente` recebe assim). Sem isso, ORA-01031 na geração.

## Uso

```sql
DECLARE
    v_exec NUMBER;
BEGIN
    v_exec := log_pkg.iniciar_execucao('carga_precos');
    log_pkg.info('Início');
    -- ... trabalho ...
    log_pkg.info('Fim');
    log_pkg.finalizar_execucao('OK');
EXCEPTION
    WHEN OTHERS THEN
        -- Primeira linha do handler: grava pilha e backtrace.
        log_pkg.erro;
        log_pkg.finalizar_execucao('ERRO');
        -- O log não substitui o tratamento do erro.
        RAISE;
END;
/

EXEC log_pkg_auditoria.gerar_trigger('produtos')
```

Consultas úteis: os eventos de uma execução por `id_execucao`; as execuções com `situacao = 'ERRO'` ordenadas por `inicio`; o histórico de um registro em `log_aud_alteracoes` por `tabela` e `chave`, ordenado por `momento`.

## Limitações

- Colunas LOB, LONG, RAW e de tipo objeto não são auditadas; valores acima de 4000 bytes são cortados.
- Coluna com nome entre aspas (minúsculas, espaços) não é suportada pelo gerador.
- Se a chave primária muda num `UPDATE`, a auditoria registra a chave nova.
- `log_eventos` cresce sem parar se ninguém chamar `expurgar`: agende num job diário (`DBMS_SCHEDULER`). Em volume alto, particionar por mês e descartar partições é mais barato que `DELETE`.
- Gerar o trigger enquanto há DML pendente na própria tabela, na mesma sessão, falha por trava: a transação autônoma não consegue a trava que a transação principal segura.

## Scripts

| Ordem | Script | Conteúdo |
|---|---|---|
| — | [instalar.sql](instalar.sql) | Roda todos na ordem, depois de remover a versão anterior |
| 1 | [01-tabelas.sql](01-tabelas.sql) | Execuções, eventos, auditoria |
| 2 | [02-pacote-log.sql](02-pacote-log.sql) | `log_pkg` |
| 3 | [03-pacote-auditoria.sql](03-pacote-auditoria.sql) | `log_pkg_auditoria` |
| 4 | [04-demonstracao.sql](04-demonstracao.sql) | Tabela de demonstração, texto e geração do trigger, um processo de exemplo com erro numa linha |
| 5 | [05-testes-de-aceite.sql](05-testes-de-aceite.sql) | 18 testes; os eventos de log ficam (são o objeto do teste), o resto termina com `ROLLBACK` |
| — | [99-remover.sql](99-remover.sql) | Remove tudo; pode rodar mais de uma vez |

Requer `CREATE TABLE`, `CREATE PROCEDURE` e `CREATE TRIGGER` (direto). Não usa o schema de exemplo.

## Testes de aceite

Log: abertura da execução e módulo da sessão (T01), níveis (T02 a T04), sobrevivência ao ROLLBACK (T05), erro com pilha e backtrace (T06), fechamento da execução (T07), expurgo só do que passou do prazo (T08). Auditoria: texto gerado (T09), recusa de nome com injeção e de tabela inexistente (T10, T11), insert, update de uma coluna, update sem mudança, troca por NULL e delete (T12 a T16), auditoria desfeita com a alteração (T17), geração sem `COMMIT` da transação de quem chamou (T18).

A saída termina com `18 de 18 testes passaram`.

## Para ir além

- Contexto em chave e valor por evento (id do pedido, arquivo carregado), numa tabela filha ou em JSON.
- Gravar o log também em `DBMS_OUTPUT` quando o nível for DEBUG, para quem roda no SQL*Plus.
- Alternativas nativas: Unified Auditing (seção 13, tópico 12) para auditoria de quem acessou; Flashback Data Archive para histórico completo de linhas sem trigger. O trigger continua útil quando se quer coluna a coluna, com o id da execução.
- O projeto de código aberto OraOpenSource Logger, mais completo, segue as mesmas ideias.
