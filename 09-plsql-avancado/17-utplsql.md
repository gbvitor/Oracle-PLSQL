# Testes unitários com utPLSQL

[utPLSQL](https://github.com/utPLSQL/utPLSQL) é o framework de testes unitários mais usado para PL/SQL: código aberto, testes escritos em PL/SQL, organização por anotações em comentário (como JUnit), relatórios para integração contínua e medição de cobertura.

## Instalação (uma vez por banco, pelo DBA)

1. Baixar a última versão em [releases](https://github.com/utPLSQL/utPLSQL/releases) e descompactar.
2. Na pasta `source`, conectado como DBA: `@install_headless.sql`. O script cria o schema `UT3`, os objetos do framework e sinônimos públicos (`ut`, `ut_runner`...). Usuário, senha e tablespace podem ser passados como parâmetros; veja o README da versão.
3. Conferir: `SELECT ut.version() FROM dual;`

Em banco de desenvolvimento ou no container Free, a instalação leva poucos minutos. Não instale em produção sem combinar com o DBA: são algumas centenas de objetos.

## Estrutura de um teste

Uma suite é uma package. As anotações ficam na **especificação**, em comentários que começam com `--%`:

```sql
CREATE OR REPLACE PACKAGE test_valor_liquido IS
    --%suite(Valor líquido do item)

    --%test(Sem desconto: quantidade vezes preço)
    PROCEDURE sem_desconto;

    --%test(Desconto acima de 100% é recusado)
    --%throws(-20001)
    PROCEDURE desconto_invalido;
END;
/
```

O corpo contém os testes, cada um com uma ou mais **expectativas**:

```sql
PROCEDURE sem_desconto IS
BEGIN
    ut.expect(valor_liquido(20, 29.90, 0)).to_equal(598);
END;
```

## Anotações principais

| Anotação | Uso |
|---|---|
| `--%suite(descrição)` | Marca a package como suite (obrigatória, primeira) |
| `--%suitepath(a.b.c)` | Agrupa suites numa hierarquia |
| `--%test(descrição)` | Marca a procedure seguinte como teste |
| `--%beforeall`, `--%afterall` | Preparação e limpeza da suite |
| `--%beforeeach`, `--%aftereach` | Antes e depois de cada teste |
| `--%throws(-20001, NO_DATA_FOUND)` | O teste passa se a exceção indicada for levantada |
| `--%disabled` | Desliga o teste sem apagá-lo |
| `--%rollback(auto)` | Padrão: cada teste roda dentro de savepoint e é desfeito no fim |
| `--%context(nome)` ... `--%endcontext` | Subgrupo de testes dentro da suite |

## Expectativas

```sql
ut.expect(valor).to_equal(esperado);
ut.expect(valor).to_be_null();
ut.expect(valor).not_to_be_null();
ut.expect(valor).to_be_greater_than(0);
ut.expect(texto).to_be_like('%Ltda');
ut.expect(cursor_real).to_equal(cursor_esperado);
```

A comparação de **cursores** (ou de coleções, JSON e objetos) é o recurso que mais diferencia o utPLSQL: compara linha a linha e coluna a coluna o resultado de uma consulta, de uma function que devolve `SYS_REFCURSOR` ou de uma pipelined, e mostra a diferença quando falha.

## Executar

```sql
EXEC ut.run('test_valor_liquido')
EXEC ut.run()
SELECT * FROM TABLE(ut.run('test_valor_liquido'));
```

- `ut.run()` sem argumento roda todas as suites do schema atual.
- O relatório padrão (`ut_documentation_reporter`) imprime cada teste com o resultado; `ut_junit_reporter` e `ut_sonar_test_reporter` geram XML para ferramentas de CI.
- O **utPLSQL-cli** roda os testes fora do banco, para pipeline de CI (GitHub Actions, Jenkins, GitLab).
- Cobertura: `ut_coverage_html_reporter` mostra que linhas do código testado foram executadas.

## O que testar

Testes unitários pagam mais em regra de negócio com casos de borda: cálculo de valor, validação de limite, conversão, classificação. Teste a fronteira (zero, NULL, limite exato, um acima), o caminho de erro e o resultado de consultas importantes. Não vale a pena testar o que só repassa dados sem regra.

## Documentação

- [utPLSQL — documentação](https://www.utplsql.org/utPLSQL/latest/)
- [utPLSQL — anotações](https://www.utplsql.org/utPLSQL/latest/userguide/annotations.html)
- [utPLSQL — expectativas](https://www.utplsql.org/utPLSQL/latest/userguide/expectations.html)
