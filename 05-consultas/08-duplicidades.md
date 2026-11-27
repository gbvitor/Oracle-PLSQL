# Encontrar e remover duplicidades

## Antes de tudo: o que é "duplicado"

Duplicidade é sempre em relação a uma **chave de negócio**: o mesmo documento, o mesmo e-mail, o mesmo produto no mesmo pedido. Defina a chave antes de escrever a consulta. Linhas idênticas em todas as colunas são raras; o caso comum é a mesma chave com outras colunas diferentes (datas, grafias, valores), e aí é preciso decidir **qual** linha fica.

## Encontrar

| Pergunta | Forma |
|---|---|
| Quais chaves estão repetidas e quantas vezes | `GROUP BY chave HAVING COUNT(*) > 1` |
| Todas as linhas de cada chave repetida, lado a lado | `COUNT(*) OVER (PARTITION BY chave)` numa inline view e filtro `> 1` |
| Qual linha de cada grupo é a "boa" | `ROW_NUMBER() OVER (PARTITION BY chave ORDER BY critério)`: a de número 1 fica |

## Duplicidade "quase igual"

Cadastros digitados à mão repetem a mesma entidade com grafias diferentes: maiúsculas, espaços extras, pontuação, acento ("Papelaria Central Ltda" e "PAPELARIA CENTRAL LTDA.", "Bem Estar" e "Bem-Estar"). Para encontrá-los, compare uma **versão normalizada** da chave:

```sql
UPPER(REGEXP_REPLACE(TRANSLATE(nome, 'acentuados', 'sem acento'), '[^[:alnum:]]'))
```

Isso mostra candidatos para revisão; a decisão de unificar é de negócio. Documento (CPF/CNPJ) só com dígitos costuma ser uma chave mais confiável que nome.

## Remover

```sql
DELETE FROM tabela
 WHERE ROWID IN (SELECT rid
                   FROM (SELECT ROWID AS rid,
                                ROW_NUMBER() OVER (PARTITION BY chave ORDER BY critério) AS rn
                           FROM tabela)
                  WHERE rn > 1);
```

- `ROWID` identifica a linha física mesmo quando todas as colunas são iguais.
- O `ORDER BY` define qual fica (a mais recente, a mais completa, a de menor id).
- **Antes de apagar**: rode o `SELECT` interno e confira as linhas; guarde uma cópia (`CREATE TABLE ... AS SELECT` das linhas que serão apagadas); verifique se outras tabelas apontam para as linhas removidas e precisam ser religadas para a que ficou.

## Impedir que volte

Depois de limpar, crie uma constraint `UNIQUE` na chave (ou um índice único sobre a versão normalizada, com índice baseado em função). Sem isso, a duplicidade volta na próxima carga.

## Documentação oficial

- [SQL Language Reference — ROW_NUMBER](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/ROW_NUMBER.html)
