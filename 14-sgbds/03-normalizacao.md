# Normalização e desnormalização

Normalizar é organizar as tabelas para que **cada fato fique guardado num lugar só**. O objetivo não é teórico: dado repetido em vários lugares diverge, e a pergunta "qual é o certo?" não tem resposta.

## As formas normais, com o schema de exemplo

**1FN: valores atômicos, sem grupos repetidos.**
Errado: `pedidos(id, cliente, produto1, qtd1, produto2, qtd2, produto3, qtd3)` ou uma coluna `produtos = 'mouse,teclado'`.
Certo: uma linha por item, em `itens_pedido`. Um pedido com 4 itens não exige mudar a tabela, e "quantos pedidos têm teclado?" é uma consulta simples.

**2FN: em chave composta, nenhuma coluna depende só de parte da chave.**
A chave de `itens_pedido` é `(id_pedido, nr_item)`. Uma coluna `data_pedido` ali dependeria só de `id_pedido`: seria repetida em cada item e poderia divergir entre os itens do mesmo pedido. Ela fica em `pedidos`.

**3FN: nenhuma coluna depende de outra coluna que não é chave.**
Uma coluna `nome_departamento` em `funcionarios` dependeria de `id_departamento`, não do funcionário. Renomear o departamento exigiria atualizar todos os funcionários dele. O nome fica em `departamentos`, e `funcionarios` guarda só o `id_departamento`.

**BCNF** (Boyce-Codd) aperta a 3FN para casos com várias chaves candidatas sobrepostas. 4FN e 5FN tratam dependências multivaloradas e de junção; aparecem pouco no dia a dia.

Resumo popular da 3FN: cada coluna depende **da chave, da chave inteira e de nada além da chave**.

## O que parece desnormalização e não é

`itens_pedido.preco_unitario` repete o preço de `produtos.preco_unitario`? Não: são fatos diferentes. O de `produtos` é o preço de tabela **hoje**; o do item é o preço **praticado na venda**, que não pode mudar quando a tabela de preço mudar. O mesmo vale para endereço de entrega no pedido (o cliente pode se mudar depois) e alíquota de imposto na nota.

A pergunta que separa os dois casos: *se o valor de origem mudar amanhã, este aqui deve mudar junto?* Se sim, é cópia e deveria ser referência. Se não, é um fato histórico próprio.

## Desnormalização consciente

Guardar dado derivado ou repetido de propósito, por desempenho ou simplicidade de consulta:

| Forma | Exemplo | Quem mantém |
|---|---|---|
| Total guardado | `pedidos.valor_total` | Trigger (seção 09, tópico 05) ou a rotina que grava os itens |
| Tabela de resumo | Vendas por mês e cliente | Materialized view (seção 07, tópico 06), job noturno |
| Coluna repetida para filtro | `uf` do cliente copiada no pedido | Rotina de gravação |
| Modelo dimensional | Data warehouse (tópico 04) | Processo de carga (ETL) |

Toda desnormalização cria uma obrigação: **manter a cópia em dia** e ter uma conferência que detecte divergência (seção 09, tópico 05, passo 3). Desnormalize quando houver um problema medido de desempenho, não por antecipação.

## Sinais de modelo mal normalizado

- Colunas numeradas (`telefone1`, `telefone2`, `telefone3`).
- Listas separadas por vírgula numa coluna.
- `UPDATE` que precisa alterar muitas linhas para mudar um único fato (o nome de uma categoria).
- Relatórios que dão números diferentes conforme a tabela de onde se lê o mesmo dado.
- Colunas que só fazem sentido para alguns tipos de registro (subtipo misturado: metade das colunas NULL em cada linha).

## Documentação

- [Oracle Database Concepts — Tables and Table Clusters: Overview](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/tables-and-table-clusters.html)
- E. F. Codd, *A Relational Model of Data for Large Shared Data Banks* (1970): o artigo que fundou o modelo relacional
