# Direitos de execução: AUTHID DEFINER e CURRENT_USER

Quando outro usuário executa uma procedure sua, com que privilégios ela roda, e em que schema ela procura os nomes de tabela? A cláusula `AUTHID` decide.

```sql
CREATE OR REPLACE PROCEDURE registrar (p_texto VARCHAR2)
    AUTHID CURRENT_USER
IS
BEGIN
    INSERT INTO tmp_registro (texto) VALUES (p_texto);
END;
/
```

| | `AUTHID DEFINER` (padrão) | `AUTHID CURRENT_USER` |
|---|---|---|
| Privilégios usados | Os do **dono** da rotina | Os de **quem chama** |
| Nome sem schema (`tmp_registro`) resolvido em | Schema do dono | Schema de quem chama |
| Roles | **Desativadas**: só privilégios concedidos diretamente ao dono valem | Ativas as roles de quem chama (em tempo de execução) |
| Quem chama precisa de grant na tabela | Não: basta `EXECUTE` na rotina | Sim |
| Uso típico | API que encapsula as tabelas: o usuário só pode fazer o que a procedure faz | Utilitário genérico que deve agir sobre os objetos de quem chama |

## Por que DEFINER é o padrão

É o modelo de segurança "acesso por API": a aplicação recebe `EXECUTE` em `pkg_vendas`, nunca `INSERT` em `pedidos`. A regra de negócio fica garantida porque não existe outro caminho para gravar.

## A armadilha das roles

Numa rotina DEFINER, as roles do dono não valem. Uma consulta que funciona no SQL Developer (onde as roles estão ativas) falha ao ser compilada dentro da procedure, com ORA-00942 ou PLS-00201. A solução é o DBA conceder o privilégio **diretamente** ao dono (`GRANT SELECT ON ... TO dono`), não via role. É o motivo de o usuário de estudo receber `SELECT ANY DICTIONARY` diretamente, além da role (seção 00).

Em rotina CURRENT_USER, as roles de quem chama valem em tempo de execução, mas o SQL **estático** ainda é verificado na compilação com os privilégios do dono. Para depender só de quem chama, o SQL precisa ser dinâmico.

## Recursos do 12c em diante

| Recurso | Para |
|---|---|
| `ACCESSIBLE BY (unidade, ...)` | Lista branca: só as unidades citadas podem chamar esta. Protege rotinas internas de uma API (PLS-00904 para os outros) |
| `GRANT role TO PROCEDURE nome` | Code-based access control: a rotina ganha os privilégios da role, sem dá-los ao dono nem a quem chama |
| `INHERIT PRIVILEGES` | Controla se uma rotina CURRENT_USER de outro dono pode rodar com os privilégios de um usuário privilegiado que a chame |

## Outros pontos

- `AUTHID` vale para a package inteira (declarado na especificação), não por rotina.
- Views e triggers rodam sempre com os direitos do dono. `[12c+]` Views aceitam `BEQUEATH CURRENT_USER` para funções chamadas por elas.
- Rotina CURRENT_USER chamada por uma rotina DEFINER "herda" o usuário corrente do DEFINER: o usuário corrente muda a cada fronteira de rotina DEFINER.

## Documentação oficial

- [PL/SQL Language Reference — Invoker's Rights and Definer's Rights](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-subprograms.html)
- [PL/SQL Language Reference — ACCESSIBLE BY Clause](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/ACCESSIBLE-BY-clause.html)
- [Database Security Guide — Managing Security for Definer's Rights and Invoker's Rights](https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/managing-security-for-definers-rights-and-invokers-rights.html)
