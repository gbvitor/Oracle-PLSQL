# Carga incremental com MERGE

## Cenário

Todo dia chega a lista de produtos do sistema de origem (uma tabela de staging carregada por arquivo, API ou database link). A carga precisa:

1. inserir os produtos novos;
2. atualizar **só** os que mudaram;
3. inativar os que deixaram de vir (sem apagar: há pedidos que os referenciam);
4. registrar quantos foram inseridos, alterados e inativados;
5. poder rodar de novo sem efeito (idempotente).

A sintaxe do `MERGE` está na seção 06 (tópico 05). Aqui, o processo inteiro.

## Os passos

| Passo | Por quê |
|---|---|
| **Validar a staging** antes de tudo: chave repetida, campo obrigatório vazio, valor fora da faixa | Chave repetida faz o `MERGE` falhar: ORA-30926 se a chave já existe no destino, ORA-00001 se é nova (as duas linhas caem no `INSERT`); dado inválido entraria no cadastro |
| `MERGE` com **condição de mudança** no `WHEN MATCHED ... WHERE` | Sem ela, todas as linhas são "atualizadas" com os mesmos valores: redo, undo, triggers e histórico de auditoria à toa, e a contagem não diz quantas mudaram de verdade |
| Inativação dos ausentes num `UPDATE` separado | O `DELETE WHERE` do `MERGE` só age em linhas que **casaram**; o que não veio na staging não passa pelo `MERGE` |
| Contagem com `SQL%ROWCOUNT` logo depois de cada comando | Log da carga; o `MERGE` dá o total (inseridas + atualizadas) |
| Uma transação para tudo, COMMIT no fim | Ou a carga entra inteira, ou nada muda |

## Comparação que trata NULL

A condição "mudou" precisa considerar NULL de um lado só:

```sql
WHEN MATCHED THEN UPDATE SET ...
WHERE DECODE(t.nome, s.nome, 0, 1) = 1
   OR DECODE(t.preco_unitario, s.preco_unitario, 0, 1) = 1
```

`t.nome <> s.nome` deixaria passar a troca de NULL por um valor.

## Incremental na origem: marca d'água

Quando a origem é grande, em vez de comparar tudo, busca-se só o que mudou desde a última carga, por uma coluna de data de alteração:

1. Tabela de controle com a última `data_alteracao` carregada.
2. Staging carregada com `WHERE data_alteracao > :ultima_marca`.
3. Depois do `MERGE`, a marca avança para o maior valor carregado (não para `SYSDATE`, para não perder o que foi alterado durante a carga).

Limitações: exclusões na origem não aparecem (precisam de exclusão lógica ou de uma comparação completa periódica), e a coluna de data precisa ser confiável.

## Documentação oficial

- [SQL Language Reference — MERGE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/MERGE.html)
