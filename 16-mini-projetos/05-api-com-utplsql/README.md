# 05 — API em PL/SQL com utPLSQL

## Enunciado

Expor o cadastro de clientes como uma **API em PL/SQL**: a aplicação (tela, serviço REST, integração) não faz `INSERT` nem `UPDATE` na tabela; chama a package. A package:

- valida e normaliza os dados (CPF/CNPJ, inclusive alfanumérico; e-mail; UF; limite);
- devolve erros com código fixo e exceção com nome, que quem chama pode tratar;
- impede que duas telas abertas sobre o mesmo cliente sobrescrevam uma a alteração da outra (**concorrência otimista** por versão);
- oferece consulta paginada com filtros e o cliente em JSON.

E testar tudo com **utPLSQL**, o framework de testes unitários de PL/SQL (seção 09, tópico 17), e também com um bloco sem framework, para quem não pode instalar nada.

## Modelo

| Coluna de `api_clientes` | Regra |
|---|---|
| `id_cliente` | Identity |
| `tipo_pessoa` | Deduzido do documento: 11 posições = F, 14 = J |
| `documento` | Sem máscara, `UNIQUE`; texto (zero à esquerda, CNPJ com letras) |
| `nome` | Obrigatório; espaços repetidos reduzidos a um |
| `email` | Opcional; minúsculas; formato `algo@dominio.ext` |
| `uf` | Uma das 27 siglas |
| `limite_credito` | ≥ 0, duas casas |
| `ativo` | `S` / `N`; inativo não se altera |
| `versao` | Começa em 1; toda alteração soma 1 |
| `criado_em`, `criado_por`, `alterado_em`, `alterado_por` | Preenchidos pela package |

## A API

| Rotina | Faz |
|---|---|
| `criar(nome, documento, uf, email, limite)` → id | Valida, normaliza e grava |
| `alterar(id, versao, nome, uf, email, limite)` | Grava se a versão informada ainda é a atual |
| `inativar(id, versao)` | Idem, marcando `ativo = 'N'` |
| `obter(id)` → registro | A linha inteira (`api_clientes%ROWTYPE`) |
| `obter_json(id)` → texto | `{"id":..,"tipoPessoa":..,"ativo":true,..}` |
| `listar(uf, nome_contem, pagina, tamanho)` → `SYS_REFCURSOR` | Filtros opcionais, ordem por nome, até 100 por página |
| `documento_valido(doc)` → `BOOLEAN` | Para a tela validar antes de enviar |

## Decisões de projeto

| Decisão | Por quê |
|---|---|
| **Concorrência otimista** (`UPDATE ... WHERE versao = :versao_lida`) | A tela fica aberta minutos; travar a linha (`FOR UPDATE`) durante esse tempo bloquearia todo mundo. Com a versão, ninguém espera: quem salva por último com uma versão velha recebe ORA-20506 e relê. Sem isso, a segunda gravação apagaria em silêncio a primeira (*lost update*, testes T18 e T19) |
| Depois de `SQL%ROWCOUNT = 0`, **diagnóstico** | O `UPDATE` não diz por que não achou linha; uma leitura depois distingue inexistente (−20505), inativo (−20509) e versão velha (−20506) |
| `UNIQUE` no documento e tradução de `DUP_VAL_ON_INDEX` | Conferir com `SELECT` antes do `INSERT` deixa uma janela em que duas sessões passam. A constraint garante; a package só dá a mensagem e o código |
| Normalizar **antes** de comparar e gravar | `529.982.247-25` e `529 982 247 25` são o mesmo CPF (teste T13). E-mail em minúsculas evita duplicidade por caixa |
| Filtro de nome **literal** (escapando `\`, `%`, `_`) | O usuário que digita `%` procura o caractere, não "qualquer coisa" (teste T05). Sem o escape, o filtro vira curinga |
| SQL **estático** com filtros opcionais (`:p IS NULL OR coluna = :p`) | Uma consulta só, com binds, sem concatenação (seção 09, tópico 09). Para tabelas grandes com muitos filtros, SQL dinâmico com binds pode dar planos melhores; aqui não compensa |
| Exceções nomeadas na especificação | `WHEN api_pkg_clientes.e_cliente_inexistente` lê melhor que comparar `SQLCODE` (teste T09) |
| `documento_valido` devolve `BOOLEAN` | Uso em PL/SQL. Em SQL do 19c, `BOOLEAN` não existe (existe no 23ai); para SQL, um wrapper que devolva `'S'`/`'N'` |

## Erros

| Código | Exceção | Quando |
|---|---|---|
| −20501 | `e_nome_obrigatorio` | Nome nulo ou em branco |
| −20502 | `e_documento_invalido` | Tamanho, caracteres ou dígito verificador inválido; todos os dígitos iguais |
| −20503 | `e_documento_duplicado` | Documento já cadastrado |
| −20504 | `e_email_invalido` | E-mail fora do formato |
| −20505 | `e_cliente_inexistente` | `obter`, `alterar` ou `inativar` de id que não existe |
| −20506 | `e_alterado_por_outro` | Versão informada não é a atual |
| −20507 | `e_uf_invalida` | UF fora da lista |
| −20508 | `e_limite_invalido` | Limite nulo, negativo ou com mais de 2 casas |
| −20509 | `e_cliente_inativo` | Alterar ou inativar cliente inativo |
| −20510 | `e_parametro_invalido` | Página menor que 1 ou tamanho fora de 1 a 100 |

Ordem das validações em `criar`: nome, UF, e-mail, limite, documento.

## Scripts

| Ordem | Script | Conteúdo |
|---|---|---|
| — | [instalar.sql](instalar.sql) | Remove a versão anterior, cria, carrega, roda os testes sem framework e, se houver utPLSQL, a suite |
| 1 | [01-tabelas.sql](01-tabelas.sql) | `api_clientes` |
| 2 | [02-pacote.sql](02-pacote.sql) | `api_pkg_clientes` |
| 3 | [03-carga.sql](03-carga.sql) | Cinco clientes criados pela API, com máscaras e espaços |
| 4 | [04-testes-de-aceite.sql](04-testes-de-aceite.sql) | 29 verificações sem framework; termina com `ROLLBACK` |
| 5 | [05-suite-utplsql.sql](05-suite-utplsql.sql) | Suite `test_api_pkg_clientes` (18 testes em 4 contextos) e execução |
| 6 | [06-executar-utplsql.sql](06-executar-utplsql.sql) | Formas de rodar: um teste, por suitepath, como consulta, JUnit, cobertura em HTML |
| — | [aviso-sem-utplsql.sql](aviso-sem-utplsql.sql) | Mensagem quando o utPLSQL não está instalado |
| — | [99-remover.sql](99-remover.sql) | Remove tudo; pode rodar mais de uma vez |

Requer `CREATE TABLE` e `CREATE PROCEDURE`. A suite exige o utPLSQL instalado no banco (por DBA, uma vez). Não usa o schema de exemplo.

## Os dois jeitos de testar, lado a lado

| | Bloco sem framework (04) | utPLSQL (05) |
|---|---|---|
| Instalação | Nenhuma | utPLSQL no banco |
| Isolamento | `ROLLBACK` no fim do bloco; testes em sequência dependem do estado anterior | Cada teste num savepoint, desfeito ao fim; `--%beforeeach` cria os dados de cada um |
| Teste de erro | `BEGIN ... EXCEPTION WHEN OTHERS` e comparação de `SQLCODE` | `--%throws(-20501)` |
| Comparar resultado de consulta | Ler o cursor e montar texto | `ut.expect(cursor).to_equal(cursor)` compara linhas e colunas |
| Relatório | `DBMS_OUTPUT` | Texto, JUnit para integração contínua, cobertura de código |
| Rodar um teste só | Não | `ut.run('test_api_pkg_clientes.versao_velha')` |

O bloco sem framework resolve para começar. Quando os testes passam de algumas dezenas ou entram num pipeline, o utPLSQL compensa.

## Para ir além

- Publicar a API como REST com ORDS (Oracle REST Data Services): cada rotina vira um endpoint; os códigos −205xx viram status HTTP (400, 404, 409).
- Entrada e saída em JSON (`criar_json(p_json CLOB)`), com `JSON_OBJECT_T` para ler os campos.
- Histórico das alterações com o trigger gerado pelo mini-projeto 04: `EXEC log_pkg_auditoria.gerar_trigger('api_clientes')`.
- Revogar `INSERT`/`UPDATE` da aplicação na tabela e conceder só `EXECUTE` na package.
