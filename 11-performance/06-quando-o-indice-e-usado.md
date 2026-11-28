# Quando um índice é usado e quando é ignorado

A criação e os tipos de índice estão na seção 07 (tópico 04), inclusive índice baseado em função, índice composto e o caso do `IS NULL`. Este tópico trata do porquê de o otimizador usar ou não um índice que existe.

## Duas razões para não usar

1. **Não pode**: a forma da condição impede o acesso pelo índice. O índice guarda os valores da coluna; se a consulta pergunta por outra coisa (uma função da coluna, a coluna convertida), o índice não tem a resposta.
2. **Não compensa**: o índice serviria, mas o otimizador estima que ler a tabela inteira sai mais barato. Às vezes está certo; às vezes a estimativa está errada (tópicos 03 e 05).

## "Não pode": a coluna precisa estar limpa

| Condição | Problema | Forma que usa o índice |
|---|---|---|
| `TRUNC(data_pedido) = DATE '2025-03-10'` | Função na coluna | `data_pedido >= DATE '2025-03-10' AND data_pedido < DATE '2025-03-11'` |
| `id_pedido + 0 = 4242`, `valor * 1.1 > 100` | Expressão na coluna | Passe a conta para o outro lado: `valor > 100 / 1.1` |
| `UPPER(nome) = 'X'` | Função na coluna | Índice baseado em função, ou guardar normalizado |
| `codigo_ext = 100042` (coluna VARCHAR2, valor NUMBER) | **Conversão implícita da coluna**: o Oracle compara como número e aplica `TO_NUMBER(codigo_ext)` | `codigo_ext = '100042'` |
| `LIKE '%42'` | Curinga no início: não há por onde começar no índice | `LIKE '10004%'` usa; para busca por sufixo, índice em `REVERSE` ou Oracle Text |
| `status <> 'ENTREGUE'`, `NOT IN (...)` | Desigualdade não delimita faixa | `status IN ('ABERTO', 'CANCELADO')` |
| `NVL(coluna, 0) = 0` | Função na coluna | `(coluna = 0 OR coluna IS NULL)` |

### A regra da conversão implícita

Quando texto e número são comparados, o Oracle converte o **texto em número**. Se o texto é a coluna, a coluna é convertida em toda linha e o índice dela não serve. Se o texto é o valor (`id_cliente = '42'`), só o valor é convertido e o índice serve. O mesmo vale para `DATE` contra texto (a coluna DATE fica intacta, o texto é convertido) e para binds com tipo errado vindos da aplicação (tópico 03, passo 5). A seção `Predicate Information` do plano denuncia: `filter(TO_NUMBER("CODIGO_EXT")=100042)`.

Além do desempenho, há risco de erro: se alguma linha de `codigo_ext` tiver texto não numérico, a consulta inteira falha com ORA-01722.

## "Não compensa": seletividade e clustering factor

Acesso por índice custa, por linha, uma leitura de bloco da tabela. Para muitas linhas, a leitura completa (com leituras grandes, multibloco) ganha. O ponto de virada não é uma porcentagem fixa; depende muito do **clustering factor** (seção 10, tópico 04):

- Dados **na ordem do índice** (o `id_pedido`, inserido em sequência): linhas vizinhas no índice estão no mesmo bloco. Ler 10% da tabela pelo índice lê só ~10% dos blocos. O índice compensa até frações grandes.
- Dados **espalhados** (a `data_pedido` gerada fora de ordem, ou `id_cliente`): cada linha está num bloco diferente. Ler 10% pelo índice lê quase todos os blocos, e várias vezes. A leitura completa ganha bem antes.

Por isso duas consultas que devolvem a mesma quantidade de linhas podem ter planos diferentes, ambos corretos. O script mostra o caso.

## Documentação oficial

- [SQL Tuning Guide — Optimizer Access Paths: Index Access](https://docs.oracle.com/en/database/oracle/oracle-database/19/tgsql/optimizer-access-paths.html)
- [SQL Language Reference — Implicit Data Conversion](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Data-Type-Comparison-Rules.html)
