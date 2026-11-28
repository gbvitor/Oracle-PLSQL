# Auditoria de alterações com trigger e tabela de histórico

## Cenário

O financeiro quer saber, para os clientes, **quem mudou o limite de crédito, de quanto para quanto e quando**, e o mesmo para e-mail, cidade e situação (ativo/inativo). A consulta precisa responder "qual era o limite do cliente 1 em 10 de março?" e "o que o usuário X alterou ontem?".

## Desenho

Uma tabela de histórico em formato **coluna a coluna** (uma linha por campo alterado), preenchida por um trigger `AFTER ... FOR EACH ROW`:

| Coluna | Conteúdo |
|---|---|
| `tabela`, `chave` | Onde mudou |
| `operacao` | `I`, `U`, `D` |
| `coluna`, `valor_antigo`, `valor_novo` | O quê, de quanto para quanto (como texto) |
| `usuario`, `modulo`, `maquina`, `momento` | Quem, por onde, quando |

O formato coluna a coluna serve qualquer tabela com a mesma estrutura de histórico e responde direto a "quem mexeu no limite". A alternativa é uma tabela espelho (`clientes_hist`, com todas as colunas e a operação), que guarda a linha inteira a cada mudança: mais simples de escrever, mais espaço, e a pergunta "o que mudou" exige comparar linhas.

## Cuidados no trigger

- **Comparação que trata NULL**: `:OLD.email <> :NEW.email` é desconhecida quando um dos lados é NULL, e a mudança de NULL para um valor não seria registrada. Use `DECODE(:OLD.email, :NEW.email, 0, 1) = 1` (o `DECODE` trata NULL = NULL) ou compare com `NVL` dos dois lados.
- **Registrar só o que mudou**: `UPDATE clientes SET limite_credito = limite_credito` não deve gerar histórico.
- **Quem**: `USER` é o usuário do banco; com pool de conexões é sempre o mesmo. O usuário real da aplicação vem de `SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER')`, se a aplicação o preencher (seção 13, tópico 06).
- **Mesma transação**: o histórico é gravado na transação do DML. Se o DML for desfeito, o histórico também; é o comportamento certo para histórico de dados. (Para registrar *tentativas*, inclusive as desfeitas, seria transação autônoma.)
- **Volume**: carga em massa na tabela auditada gera o mesmo volume no histórico. Desligar o trigger na carga é decisão a registrar, não atalho.

## Quando não é a ferramenta certa

| Necessidade | Ferramenta |
|---|---|
| Histórico recente, sem código | Flashback Version Query (seção 13, tópico 09), dentro do alcance do undo |
| Prova para auditoria de segurança, protegida do próprio DBA da aplicação | Unified Auditing (seção 13, tópico 12) |
| Histórico completo de longo prazo, sem trigger | Flashback Data Archive |
| Histórico de negócio consultado pela aplicação | **Este caso** |

## Documentação oficial

- [PL/SQL Language Reference — PL/SQL Triggers](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-triggers.html)
