# BULK COLLECT, LIMIT, FORALL e SAVE EXCEPTIONS

Cada instrução SQL executada de dentro do PL/SQL é uma **troca de contexto** entre os dois motores. Um laço que busca e grava linha a linha faz duas trocas por linha. Processamento em lote reduz isso a poucas trocas por lote:

| Recurso | Faz em lote |
|---|---|
| `BULK COLLECT INTO` | A leitura: traz muitas linhas para uma coleção numa ida |
| `FORALL` | A gravação: manda um DML com a coleção inteira de valores numa ida |

Antes de tudo: se a regra cabe num `UPDATE`, `MERGE` ou `INSERT ... SELECT`, uma instrução SQL ganha de qualquer PL/SQL em lote. Lote serve quando há lógica por linha que o SQL não expressa bem.

## BULK COLLECT

```sql
SELECT id_cliente, nome BULK COLLECT INTO v_ids, v_nomes FROM clientes;
SELECT * BULK COLLECT INTO v_clientes FROM clientes;
FETCH c BULK COLLECT INTO v_lote LIMIT 500;
```

- O destino é coleção (normalmente associative array ou nested table); vem **densa**, de 1 a COUNT.
- **Sem linhas não é erro**: a coleção fica com COUNT 0. Não há NO_DATA_FOUND nem TOO_MANY_ROWS.
- Sem `LIMIT`, tudo vai para a memória da sessão (PGA) de uma vez. Para tabela que pode crescer, use cursor com `LIMIT`.

## O laço com LIMIT

```sql
OPEN c;
LOOP
    FETCH c BULK COLLECT INTO v_lote LIMIT 500;
    EXIT WHEN v_lote.COUNT = 0;

    -- processa v_lote(1 .. v_lote.COUNT)
END LOOP;
CLOSE c;
```

O teste de saída é `v_lote.COUNT = 0`, **depois** do FETCH. `EXIT WHEN c%NOTFOUND` logo depois do FETCH perde o último lote incompleto: o FETCH que trouxe 4 de 500 linhas já marca `%NOTFOUND = TRUE`. (Se preferir `%NOTFOUND`, coloque-o no fim do laço, depois de processar.)

Tamanho do lote: entre 100 e 1000 costuma capturar quase todo o ganho. Acima disso, a memória cresce e o tempo quase não muda.

## FORALL

```sql
FORALL i IN 1 .. v_ids.COUNT
    UPDATE produtos SET preco_unitario = v_precos(i) WHERE id_produto = v_ids(i);
```

- **Uma instrução DML só** por FORALL. Não é laço: não aceita IF, chamada de procedure nem outro comando no corpo.
- Coleção esparsa: `FORALL i IN INDICES OF v_ids` (usa os índices que existem) ou `VALUES OF v_posicoes` (usa uma coleção de índices).
- `SQL%ROWCOUNT` traz o total; `SQL%BULK_ROWCOUNT(i)` traz quantas linhas a execução `i` afetou.
- `RETURNING ... BULK COLLECT INTO` devolve os valores gravados em coleções.

## SAVE EXCEPTIONS

Sem a cláusula, o primeiro erro interrompe o FORALL: as execuções anteriores continuam feitas (na transação), a que falhou é desfeita e as seguintes não acontecem.

Com `SAVE EXCEPTIONS`, o FORALL executa todas, guarda os erros e, no fim, levanta **ORA-24381**. O detalhe fica em `SQL%BULK_EXCEPTIONS`:

| Atributo | Conteúdo |
|---|---|
| `SQL%BULK_EXCEPTIONS.COUNT` | Quantas execuções falharam |
| `SQL%BULK_EXCEPTIONS(j).ERROR_INDEX` | Índice `i` da execução que falhou |
| `SQL%BULK_EXCEPTIONS(j).ERROR_CODE` | Código do erro **positivo** (1 para ORA-00001); mensagem com `SQLERRM(-codigo)` |

Alternativa sem PL/SQL: `INSERT ... SELECT ... LOG ERRORS` (seção 06, tópico 10).

## Documentação oficial

- [PL/SQL Language Reference — Bulk SQL and Bulk Binding](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/bulk-sql-and-bulk-binding.html)
- [PL/SQL Language Reference — FORALL Statement](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/FORALL-statement.html)
