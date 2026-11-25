# Modelo relacional

## O que é

O modelo relacional guarda dados em **tabelas** (relações). Cada tabela descreve um tipo de coisa — cliente, pedido, produto — e cada **linha** é uma ocorrência dela. Cada **coluna** é um atributo com tipo definido. As tabelas se ligam por valores em comum, não por ponteiros: o pedido sabe a qual cliente pertence porque guarda o `id_cliente`.

## Vocabulário

| Termo | Significado | No schema de exemplo |
|---|---|---|
| Tabela | Conjunto de linhas com as mesmas colunas | `clientes` |
| Linha (tupla, registro) | Uma ocorrência | O cliente 3 |
| Coluna (atributo, campo) | Uma característica, com tipo | `clientes.uf`, `CHAR(2)` |
| Domínio | Conjunto de valores aceitos por uma coluna | `tipo_pessoa` só aceita `F` ou `J` |
| Chave primária (PK) | Coluna(s) que identificam a linha de forma única e nunca são nulas | `clientes.id_cliente` |
| Chave composta | PK formada por mais de uma coluna | `itens_pedido (id_pedido, nr_item)` |
| Chave candidata / única (UK) | Outra coluna que também não pode repetir | `clientes.documento` |
| Chave estrangeira (FK) | Coluna que aponta para a PK de outra tabela | `pedidos.id_cliente` → `clientes` |
| Auto-relacionamento | FK que aponta para a própria tabela | `funcionarios.id_gerente` |
| Cardinalidade | Quantas linhas de um lado se ligam ao outro | Um cliente tem zero ou muitos pedidos |

## Integridade

O banco garante as regras do modelo por meio de **constraints**, e não só pela aplicação:

- **Integridade de entidade** — toda linha tem PK, e a PK não é nula nem repetida.
- **Integridade referencial** — o valor da FK existe na tabela referenciada (ou é nulo, se a coluna permitir). Não dá para inserir um pedido de cliente inexistente nem apagar um cliente que tem pedidos, a menos que a FK tenha `ON DELETE CASCADE` ou `ON DELETE SET NULL`.
- **Integridade de domínio** — tipo, `NOT NULL` e `CHECK` limitam os valores aceitos.

Regra prática: o que o banco consegue garantir, o banco deve garantir. Validação só na aplicação falha no primeiro script de carga ou no primeiro `UPDATE` manual.

## Normalização

Normalizar é distribuir os dados em tabelas de forma que cada fato fique gravado em um só lugar. O objetivo é evitar inconsistência: se o nome do cliente estivesse repetido em cada pedido, uma correção precisaria atualizar todos os pedidos, e bastaria esquecer um.

**1ª forma normal (1FN)** — cada coluna guarda um único valor. Uma coluna `telefones` com "1111-1111, 2222-2222" viola a 1FN; o certo é uma tabela de telefones.

**2ª forma normal (2FN)** — na tabela com chave composta, toda coluna depende da chave inteira. Em `itens_pedido (id_pedido, nr_item)`, gravar `data_pedido` violaria a 2FN, porque a data depende só de `id_pedido`; por isso ela está em `pedidos`.

**3ª forma normal (3FN)** — nenhuma coluna depende de outra coluna que não seja chave. Gravar `nome_departamento` em `funcionarios` violaria a 3FN, porque o nome depende de `id_departamento`, não do funcionário.

### Desnormalização consciente

Repetir um dado de propósito é aceitável quando ele representa **um fato diferente**. `itens_pedido.preco_unitario` parece duplicar `produtos.preco_unitario`, mas não duplica: o primeiro é o preço praticado naquela venda, o segundo é o preço de tabela de hoje. Se o item buscasse o preço no produto, todo pedido antigo mudaria de valor a cada reajuste.

## Armadilhas

- **Chave natural como PK.** CPF, placa e e-mail mudam ou têm exceções. O schema de exemplo usa chave substituta (`id_cliente`) como PK e o documento como chave única.
- **FK sem índice.** O Oracle não cria índice em FK automaticamente. Sem ele, apagar ou alterar a chave na tabela pai bloqueia a tabela filha inteira enquanto a transação durar.
- **FK que permite nulo sem intenção.** `pedidos.id_vendedor` é nulo de propósito (venda pelo site). Quando o nulo não tem significado no negócio, a coluna deve ser `NOT NULL`.

## Documentação oficial

- [Database Concepts — Tables and Table Clusters](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/tables-and-table-clusters.html)
- [Database Concepts — Data Integrity](https://docs.oracle.com/en/database/oracle/oracle-database/19/cncpt/data-integrity.html)
