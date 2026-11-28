# Erros ORA- mais comuns: causa e correção

A mensagem exata varia com o idioma da sessão (`NLS_LANGUAGE`); o número não. Para ler a pilha de um erro em PL/SQL, a primeira linha é o erro e as linhas `ORA-06512` dizem por onde ele passou (seção 09, tópico 13).

## Sintaxe e nomes

| Erro | Mensagem | Causa típica | Correção |
|---|---|---|---|
| ORA-00900 | invalid SQL statement | Comando de SQL*Plus (`DESC`, `SET`) enviado como SQL por outra ferramenta ou por `EXECUTE IMMEDIATE` | Usar o equivalente em SQL ou rodar no cliente certo |
| ORA-00904 | invalid identifier | Coluna com nome errado, alias do `SELECT` usado no `WHERE`, palavra reservada como nome, identificador entre aspas com caixa diferente | Conferir `DESC tabela`; repetir a expressão no `WHERE` ou usar subconsulta (seção 01, tópico 09) |
| ORA-00905 | missing keyword | Palavra-chave faltando (`INTO`, `THEN`, `BY`) | Revisar a sintaxe do comando |
| ORA-00907 | missing right parenthesis | Parêntese faltando, ou cláusula inválida dentro dele (`ORDER BY` em subconsulta de `IN`, tipo sem tamanho) | Conferir parênteses e o que está dentro |
| ORA-00911 | invalid character | `;` no fim do texto de `EXECUTE IMMEDIATE` ou da ferramenta; caractere especial colado | Tirar o `;` do SQL dinâmico (o bloco PL/SQL dinâmico, ao contrário, termina com `END;`) |
| ORA-00918 | column ambiguously defined | Coluna que existe nas duas tabelas do join, sem prefixo | Qualificar com o alias da tabela |
| ORA-00923 | FROM keyword not found where expected | Vírgula ou aspas faltando na lista do `SELECT`; alias com espaço sem aspas duplas | Revisar a lista de colunas |
| ORA-00933 | SQL command not properly ended | `ORDER BY` em subconsulta, `AS` antes de alias de tabela, sobra depois do fim do comando | Remover o trecho inválido (`FROM clientes c`, nunca `FROM clientes AS c`) |
| ORA-00936 | missing expression | Vírgula sobrando, coluna faltando depois de operador | Revisar a expressão |
| ORA-00942 | table or view does not exist | Nome errado, outro schema sem prefixo, ou **sem privilégio** (o Oracle não diz qual) | Conferir em `ALL_TABLES`; usar `dono.tabela` ou sinônimo; pedir `GRANT` (seção 13, tópico 04) |
| ORA-00955 | name is already used by an existing object | `CREATE` de objeto que já existe (inclusive índice com nome de constraint) | `CREATE OR REPLACE` onde existir, ou `DROP` antes; no 23ai, `IF NOT EXISTS` |
| ORA-00957 | duplicate column name | Coluna repetida no `CREATE TABLE`, no `INSERT` ou na view | Renomear ou dar alias |
| ORA-01747 | invalid user.table.column, table.column, or column specification | Palavra reservada como nome de coluna (`date`, `level`, `comment`) | Renomear a coluna |
| ORA-06550 | line N, column M | Erro de compilação num bloco anônimo; o `PLS-` que vem junto diz o motivo | Ler o `PLS-` da linha seguinte |

## Tipos, conversão e valores

| Erro | Mensagem | Causa típica | Correção |
|---|---|---|---|
| ORA-00932 | inconsistent datatypes | Comparar ou combinar tipos incompatíveis (`CLOB` em `GROUP BY`/`DISTINCT`, número com data) | Converter explicitamente; para CLOB, `DBMS_LOB.SUBSTR` |
| ORA-01722 | invalid number | Texto não numérico convertido para número, **inclusive implicitamente** (`WHERE coluna_texto = 123`); separador decimal diferente da sessão | Comparar texto com texto (`= '123'`); `TO_NUMBER` com máscara e NLS; `VALIDATE_CONVERSION` `[12.2+]` para achar as linhas ruins |
| ORA-01790 | expression must have same datatype as corresponding expression | Colunas de tipos diferentes na mesma posição de um `UNION` | `TO_CHAR` ou `CAST` em um dos lados |
| ORA-01830 | date format picture ends before converting entire input string | Texto com mais conteúdo que a máscara (hora sobrando) | Completar a máscara ou cortar o texto |
| ORA-01840 / ORA-01841 | input value not long enough / (full) year must be between -4713 and +9999 | Ano faltando ou zero; data convertida duas vezes (`TO_DATE` sobre `DATE`) | Máscara completa; não aplicar `TO_DATE` a coluna `DATE` |
| ORA-01843 | not a valid month | Máscara trocada (`DD/MM` × `MM/DD`); nome de mês noutro idioma | Conferir a ordem; fixar `NLS_DATE_LANGUAGE` |
| ORA-01847 | day of month must be between 1 and last day of month | 31/04, 30/02 | Validar a data antes |
| ORA-01858 | a non-numeric character was found where a numeric was expected | Letra onde a máscara espera número | Conferir máscara e dado |
| ORA-01861 | literal does not match format string | Separadores ou formato do texto diferentes da máscara; data sem máscara caindo no `NLS_DATE_FORMAT` | Máscara explícita; literal `DATE 'YYYY-MM-DD'` (referências, [03](03-mascaras-de-formato.md)) |
| ORA-01873 | the leading precision of the interval is too small | `INTERVAL '400' DAY` (precisão padrão de 2 dígitos) | `INTERVAL '400' DAY(3)` |
| ORA-01438 | value larger than specified precision allowed for this column | Número com mais dígitos inteiros que `NUMBER(p,s)` permite | Aumentar a precisão ou corrigir o dado |
| ORA-12899 | value too large for column "X" (actual: n, maximum: m) | Texto maior que a coluna; em `AL32UTF8`, acentos ocupam 2 bytes numa coluna `VARCHAR2(n BYTE)` | Aumentar ou usar `CHAR` semantics: `VARCHAR2(n CHAR)` |
| ORA-01476 | divisor is equal to zero | Divisão por zero | `x / NULLIF(y, 0)` |
| ORA-01489 | result of string concatenation is too long | `LISTAGG` ou `\|\|` passou de 4000 bytes | `LISTAGG ... ON OVERFLOW TRUNCATE` `[12.2+]` ou CLOB (seção 15, caso 13) |
| ORA-06502 | PL/SQL: numeric or value error | Variável pequena demais, conversão inválida em PL/SQL, `NULL` em `NOT NULL`, limite NULL em `FOR` | Aumentar a variável (ancorar com `%TYPE`); conferir a conversão |

## Restrições de integridade

| Erro | Mensagem | Causa típica | Correção |
|---|---|---|---|
| ORA-00001 | unique constraint (DONO.NOME) violated | Chave primária ou única repetida | Tratar `DUP_VAL_ON_INDEX`; `MERGE` em vez de `INSERT` quando for upsert |
| ORA-01400 | cannot insert NULL into ("DONO"."T"."C") | Coluna obrigatória sem valor | Informar o valor ou dar `DEFAULT` |
| ORA-01407 | cannot update ("DONO"."T"."C") to NULL | `UPDATE` deixando nula uma coluna obrigatória (comum com subconsulta que não acha linha) | `WHERE EXISTS` no `UPDATE`, ou `NVL` |
| ORA-02290 | check constraint (DONO.NOME) violated | Valor fora da regra do `CHECK` | Corrigir o dado; ver a regra em `USER_CONSTRAINTS.SEARCH_CONDITION` |
| ORA-02291 | integrity constraint (DONO.FK) violated - parent key not found | Filho apontando para pai que não existe | Inserir o pai antes, ou corrigir a chave |
| ORA-02292 | integrity constraint (DONO.FK) violated - child record found | Apagar pai que tem filhos | Apagar filhos antes, ou `ON DELETE CASCADE` se for a regra |
| ORA-02293 | cannot validate (DONO.NOME) - check constraint violated | Criar ou habilitar `CHECK` com dado existente que não obedece | Corrigir o dado ou `ENABLE NOVALIDATE` (seção 07, tópico 03) |
| ORA-02449 | unique/primary keys in table referenced by foreign keys | `DROP TABLE` de tabela mãe | `DROP TABLE ... CASCADE CONSTRAINTS` ou apagar as filhas antes |

## Consultas

| Erro | Mensagem | Causa típica | Correção |
|---|---|---|---|
| ORA-00913 / ORA-00947 | too many values / not enough values | Quantidade de colunas do `INSERT` diferente da dos valores | Listar as colunas no `INSERT` |
| ORA-00934 | group function is not allowed here | Agregação no `WHERE` | Usar `HAVING`, ou subconsulta |
| ORA-00937 | not a single-group group function | Coluna sem agregação junto com agregação, sem `GROUP BY` | Pôr a coluna no `GROUP BY` |
| ORA-00979 | not a GROUP BY expression | Coluna no `SELECT` ou `ORDER BY` que não está no `GROUP BY` | Pôr no `GROUP BY` ou agregar (`MAX`) |
| ORA-01427 | single-row subquery returns more than one row | Subconsulta com `=` ou escalar devolvendo várias linhas | Corrigir a correlação; `IN`; agregação; `FETCH FIRST 1 ROW ONLY` |
| ORA-01788 | CONNECT BY clause required in this query block | `LEVEL` ou `PRIOR` sem `CONNECT BY` | Adicionar `CONNECT BY` ou trocar por `ROWNUM` |
| ORA-01436 | CONNECT BY loop in user data | Ciclo na hierarquia | `CONNECT BY NOCYCLE` e `CONNECT_BY_ISCYCLE` para achar |
| ORA-30926 | unable to get a stable set of rows in the source tables | `MERGE` com duas linhas da origem para a mesma linha do destino | Deduplicar a origem (seção 15, caso 07) |
| ORA-38104 | columns referenced in the ON clause cannot be updated | `MERGE` alterando coluna usada no `ON` | Tirar a coluna do `SET` |
| ORA-01779 | cannot modify a column which maps to a non key-preserved table | `UPDATE` sobre join ou view em que a tabela alterada não tem chave preservada | `MERGE` ou `UPDATE` com subconsulta correlacionada |

## Transação, trava e concorrência

| Erro | Mensagem | Causa típica | Correção |
|---|---|---|---|
| ORA-00054 | resource busy and acquire with NOWAIT specified or timeout expired | `FOR UPDATE NOWAIT`, ou DDL em tabela com transação aberta de outra sessão (ou da própria, numa transação autônoma) | Esperar o `COMMIT`; `DDL_LOCK_TIMEOUT`; achar quem trava (seção 13, tópico 07) |
| ORA-00060 | deadlock detected while waiting for resource | Duas sessões travando as mesmas linhas em ordem inversa | Travar sempre na mesma ordem (seção 16, projeto 01). O Oracle desfaz só a instrução de uma das sessões, que deve fazer `ROLLBACK` |
| ORA-01555 | snapshot too old | Consulta longa que precisa de undo já sobrescrito; *fetch across commit* | Consulta mais rápida; não fazer `COMMIT` dentro do laço do cursor que se lê (seção 15, caso 11); `UNDO_RETENTION` (DBA) |
| ORA-08177 | can't serialize access for this transaction | Isolamento `SERIALIZABLE` e linha alterada por outra transação depois do início | Repetir a transação |
| ORA-01002 | fetch out of sequence | `FETCH` depois de `COMMIT` num cursor `FOR UPDATE`; `FETCH` depois do fim | Não fazer `COMMIT` dentro do laço do cursor `FOR UPDATE` |
| ORA-02089 | COMMIT is not allowed in a subordinate session | `COMMIT` dentro de transação distribuída controlada por outro | Deixar o `COMMIT` para o coordenador |
| ORA-14551 | cannot perform a DML operation inside a query | Function com `INSERT`/`UPDATE` chamada num `SELECT` | Chamar em PL/SQL; transação autônoma só para log (seção 09, tópico 12) |
| ORA-14552 | cannot perform a DDL, commit or rollback inside a query or DML | Function com `COMMIT` ou DDL chamada em SQL | Idem |
| ORA-06519 | active autonomous transaction detected and rolled back | Rotina autônoma terminou sem `COMMIT` ou `ROLLBACK` | Encerrar a transação dentro dela |

## PL/SQL em execução

| Erro | Mensagem | Causa típica | Correção |
|---|---|---|---|
| ORA-01403 | no data found | `SELECT INTO` sem linha; associative array com índice inexistente | Tratar `NO_DATA_FOUND`; `COUNT(*)` quando só se quer saber se existe |
| ORA-01422 | exact fetch returns more than requested number of rows | `SELECT INTO` com várias linhas | Filtro pela chave; `TOO_MANY_ROWS`; cursor |
| ORA-06511 | PL/SQL: cursor already open | `OPEN` de cursor já aberto (laço que não fecha) | `IF c%ISOPEN THEN CLOSE c; END IF;` ou cursor `FOR` |
| ORA-01001 | invalid cursor | `FETCH` ou `CLOSE` de cursor fechado | Conferir o fluxo de abertura |
| ORA-01000 | maximum open cursors exceeded | Cursores (ou REF CURSOR devolvidos à aplicação) nunca fechados | Fechar sempre, inclusive no `EXCEPTION`; ver `V$OPEN_CURSOR` |
| ORA-06530 / ORA-06531 | reference to uninitialized composite / collection | Nested table ou varray sem construtor | `v := t_lista();` antes de `EXTEND` |
| ORA-06532 / ORA-06533 | subscript outside of limit / beyond count | Índice fora da coleção | Conferir `COUNT`, `EXISTS(i)` |
| ORA-06592 | CASE not found while executing CASE statement | Comando `CASE` sem `ELSE` e sem casar | Adicionar `ELSE` |
| ORA-04091 | table T is mutating, trigger/function may not see it | Trigger de linha lendo ou alterando a própria tabela | Compound trigger, ou regra na package (seção 09, tópico 05) |
| ORA-04088 | error during execution of trigger 'DONO.TRG' | Erro dentro de um trigger; a causa vem nas linhas acima | Ler o erro original na pilha |
| ORA-24381 | error(s) in array DML | `FORALL ... SAVE EXCEPTIONS` com falhas | Ler `SQL%BULK_EXCEPTIONS` (seção 09, tópico 08) |
| ORA-20000 a ORA-20999 | (texto da aplicação) | `RAISE_APPLICATION_ERROR` do código | Ver a regra no código que levantou |

## Objetos inválidos e dependências

| Erro | Mensagem | Causa típica | Correção |
|---|---|---|---|
| ORA-04063 / ORA-06575 | ... has errors / package or function is in an invalid state | Objeto com erro de compilação | `SHOW ERRORS`; `USER_ERRORS` |
| ORA-04068 / ORA-04061 / ORA-04065 | existing state of packages has been discarded | Package recompilada enquanto a sessão tinha estado dela (variáveis de corpo) | Chamar de novo; em produção, evitar estado em package ou usar edição (EBR) |
| ORA-04021 | timeout occurred while waiting to lock object | Recompilar package que outra sessão está executando | Esperar ou compilar fora do horário |
| ORA-04098 | trigger 'DONO.TRG' is invalid and failed re-validation | Trigger com erro de compilação bloqueia o DML da tabela | Corrigir ou `ALTER TRIGGER trg DISABLE` |
| ORA-06508 | PL/SQL: could not find program unit being called | Rotina removida ou inválida durante a execução | Recompilar; conferir dependências (seção 09, tópico 15) |
| ORA-04043 | object X does not exist | `DROP`/`DESC` de objeto inexistente ou de outro schema | Conferir nome e dono |

## Privilégio, conta e espaço

| Erro | Mensagem | Causa típica | Correção |
|---|---|---|---|
| ORA-01031 | insufficient privileges | Falta privilégio de sistema ou de objeto; **privilégio por role não vale dentro de PL/SQL de direitos do dono** | `GRANT` direto ao usuário, ou `AUTHID CURRENT_USER` (seção 09, tópico 14) |
| ORA-01017 | invalid username/password; logon denied | Senha errada; senha com caixa diferente (sensível desde o 11g) | Conferir; aspas na senha com caractere especial |
| ORA-28000 | the account is locked | Tentativas de senha esgotadas ou bloqueio manual | `ALTER USER x ACCOUNT UNLOCK` (DBA) |
| ORA-28001 | the password has expired | `PASSWORD_LIFE_TIME` do perfil | Trocar a senha (seção 13, tópico 03) |
| ORA-01950 | no privileges on tablespace 'USERS' | Usuário sem cota | `ALTER USER x QUOTA 100M ON users` (DBA) |
| ORA-01653 / ORA-01654 / ORA-01688 | unable to extend table / index / table partition | Tablespace cheio | Adicionar espaço (DBA); limpar dados |
| ORA-01652 | unable to extend temp segment | Ordenação ou hash grande sem espaço no `TEMP` | Rever a consulta; aumentar o `TEMP` (DBA) |
| ORA-00018 / ORA-00020 | maximum number of sessions / processes exceeded | Limite da instância | Fechar conexões; pool; parâmetro (DBA) |

## Conexão

| Erro | Mensagem | Causa típica | Correção |
|---|---|---|---|
| ORA-12154 | TNS: could not resolve the connect identifier | Alias não existe no `tnsnames.ora` usado pelo cliente | Usar easy connect `host:porta/servico`; conferir `TNS_ADMIN` (seção 12, tópico 01) |
| ORA-12514 | TNS: listener does not currently know of service requested | Nome de serviço errado (SID no lugar do service; CDB no lugar do PDB) | Conferir com `lsnrctl status` ou `SELECT name FROM v$services` |
| ORA-12541 | TNS: no listener | Listener parado ou porta errada | Subir o listener; conferir a porta |
| ORA-12170 / ORA-12535 | TNS: connect timeout occurred | Firewall, host inalcançável | Rede |
| ORA-01033 | ORACLE initialization or shutdown in progress | Banco subindo ou PDB fechado | Esperar; `ALTER PLUGGABLE DATABASE ... OPEN` (DBA) |

## PLS- (compilação)

| Erro | Causa típica |
|---|---|
| PLS-00103 | Símbolo inesperado: `;` faltando, `END IF` escrito `ENDIF`, palavra reservada como nome |
| PLS-00201 | Identificador não declarado: nome errado, falta de privilégio direto no objeto, package de outro schema sem prefixo |
| PLS-00302 | Componente não declarado: nome de procedure ou campo de record errado; rotina que está só no corpo, não na especificação |
| PLS-00306 | Número ou tipos de argumentos errados na chamada |
| PLS-00320 | Declaração de tipo incompleta ou malformada (`%TYPE` de coluna inexistente) |
| PLS-00363 | Expressão não pode ser alvo de atribuição: atribuir a parâmetro `IN` ou constante |
| PLS-00382 | Expressão de tipo errado |
| PLS-00428 | `SELECT` sem `INTO` dentro de PL/SQL |
| PLS-00049 | Variável bind inválida: em trigger, `:NEW.coluna` com nome errado |
| PLS-00905 | Objeto inválido referenciado |

## SP2- (SQL*Plus)

| Erro | Causa típica |
|---|---|
| SP2-0042 / SP2-0734 | Comando desconhecido: linha que o SQL*Plus não reconhece (texto solto, comentário mal escrito) |
| SP2-0310 | Não conseguiu abrir o arquivo do `@`: caminho relativo ao diretório errado (`@@` resolve relativo ao script) |
| SP2-0552 | Variável bind não declarada: faltou `VARIABLE` |
| SP2-0618 / SP2-0611 | `AUTOTRACE` sem a role `PLUSTRACE` |
| `Enter value for ...` | `&` no texto (inclusive em comentário) tratado como variável de substituição: `SET DEFINE OFF` (seção 12, tópico 03) |

## Documentação oficial

- [Database Error Messages 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/errmg/index.html)
- No servidor: `oerr ora 1722` mostra causa e ação de um erro.
