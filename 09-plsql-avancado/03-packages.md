# Packages: especificação, corpo, estado, inicialização e overloading

Package agrupa procedures, functions, tipos, constantes, exceções e variáveis relacionados numa unidade só. É a forma padrão de organizar código PL/SQL em produção: procedure e function soltas são exceção.

## Duas partes

| Parte | Conteúdo | Quem vê |
|---|---|---|
| Especificação (`CREATE PACKAGE`) | Assinaturas públicas, tipos, constantes, exceções, variáveis públicas | Quem tem `EXECUTE` na package |
| Corpo (`CREATE PACKAGE BODY`) | Implementação das rotinas públicas, rotinas e variáveis **privadas**, seção de inicialização | Só o próprio corpo |

```sql
CREATE OR REPLACE PACKAGE pkg_vendas IS
    e_limite_excedido EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_limite_excedido, -20101);

    FUNCTION valor_pedido (p_id_pedido IN NUMBER) RETURN NUMBER;
    PROCEDURE validar_credito (p_id_cliente IN NUMBER, p_valor_novo IN NUMBER);
END pkg_vendas;
/

CREATE OR REPLACE PACKAGE BODY pkg_vendas IS
    FUNCTION valor_pedido (p_id_pedido IN NUMBER) RETURN NUMBER IS ... END;
    PROCEDURE validar_credito (...) IS ... END;
END pkg_vendas;
/
```

Chamada: `pkg_vendas.valor_pedido(1001)`.

## Por que usar

- **Encapsulamento**: o que está só no corpo não pode ser chamado de fora (PLS-00302). A especificação é o contrato; o corpo pode mudar à vontade.
- **Menos invalidação em cascata**: recompilar só o corpo não invalida quem depende da package, desde que a especificação não mude (tópico 15).
- **Estado de sessão**: variáveis declaradas fora das rotinas (na especificação ou no corpo) mantêm o valor entre chamadas, durante toda a sessão.
- **Organização**: exceções, constantes e tipos comuns num lugar só (a "package de exceções" citada na seção 08).
- **Carga**: a package inteira é carregada na memória na primeira chamada.

## Estado de package

- Cada sessão tem a **sua cópia** das variáveis. Duas sessões não compartilham estado; para isso, tabela ou contexto global.
- A **seção de inicialização** (`BEGIN` no fim do corpo) roda uma vez por sessão, na primeira referência à package.
- Variável pública na especificação pode ser alterada por qualquer chamador. Prefira variável privada no corpo com function de leitura.
- **ORA-04068** ("o estado existente dos pacotes foi descartado"): se uma sessão tem estado carregado e outra sessão recompila a package, a primeira recebe esse erro na chamada seguinte. A chamada depois dela funciona, com o estado zerado. Em produção, é o motivo de evitar estado em package usada por pool de conexões e de fazer deploy fora do horário de uso.
- Packages **sem estado** (sem variáveis nem cursores no nível da package; só rotinas, tipos e constantes com valor literal) não têm o que perder e não levantam ORA-04068 ao serem recompiladas.
- `PRAGMA SERIALLY_REUSABLE` faz o estado durar só uma chamada ao servidor, em vez da sessão inteira.

## Overloading

Duas ou mais rotinas com o mesmo nome e parâmetros de tipos ou quantidades diferentes. O compilador escolhe pela chamada:

```sql
FUNCTION formatar (p_valor IN NUMBER) RETURN VARCHAR2;
FUNCTION formatar (p_data  IN DATE)   RETURN VARCHAR2;
```

Não funciona sobrecarregar só pelo modo (`IN` versus `OUT`), só pelo tipo de retorno, ou por tipos da mesma família (`VARCHAR2` versus `CHAR`, `INTEGER` versus `NUMBER`): a chamada fica ambígua (PLS-00307).

## Limites ao usar a partir de SQL

- Function pública de package pode ser usada em SQL normalmente.
- **Constantes e variáveis de package não podem ser lidas diretamente em SQL** no 19c. Exponha por uma function ou passe o valor como bind.
- Tipos declarados em package podem ser usados em SQL a partir do 12c em alguns contextos (por exemplo, `TABLE()` sobre coleção de package); para uso geral em SQL, crie o tipo com `CREATE TYPE`.

## Ordem de compilação

A especificação precisa existir antes do corpo. Corpo inválido não invalida a especificação; especificação recompilada com mudança invalida o corpo e todos os dependentes.

## Documentação oficial

- [PL/SQL Language Reference — PL/SQL Packages](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-packages.html)
- [PL/SQL Language Reference — Overloaded Subprograms](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-subprograms.html)
- [PL/SQL Language Reference — SERIALLY_REUSABLE Pragma](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/SERIALLY_REUSABLE-pragma.html)
