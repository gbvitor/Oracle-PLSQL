# Pipelined table functions

Uma **table function** devolve uma coleção que o SQL consulta como se fosse tabela:

```sql
SELECT * FROM TABLE(minha_funcao(...));
```

A versão **pipelined** devolve as linhas **uma a uma**, à medida que são produzidas (`PIPE ROW`), em vez de montar a coleção inteira na memória e devolver no fim. O consumidor começa a receber linhas antes de a function terminar, e a memória usada não cresce com o volume.

```sql
CREATE TYPE t_datas AS TABLE OF DATE;
/

CREATE OR REPLACE FUNCTION meses (p_inicio DATE, p_qtd PLS_INTEGER)
    RETURN t_datas PIPELINED
IS
BEGIN
    FOR i IN 0 .. p_qtd - 1 LOOP
        PIPE ROW (ADD_MONTHS(TRUNC(p_inicio, 'MM'), i));
    END LOOP;
    RETURN;
END;
/

SELECT column_value AS mes FROM TABLE(meses(DATE '2025-01-01', 24));
```

- O tipo de retorno é uma coleção (nested table ou VARRAY). Pode ser criado com `CREATE TYPE` ou declarado na especificação de uma package; no segundo caso, o Oracle cria tipos de sistema por baixo.
- Coleção de escalar: a coluna se chama `COLUMN_VALUE`. Coleção de objeto (`CREATE TYPE ... AS OBJECT`): uma coluna por atributo.
- `RETURN;` sem valor encerra a function.
- Nas versões recentes (12.2 em diante), a palavra `TABLE()` é opcional: `SELECT * FROM meses(...)`.

## Usos típicos

| Uso | Exemplo |
|---|---|
| Gerar linhas que não existem em tabela | Calendário, faixas numéricas, para achar lacunas com LEFT JOIN |
| Quebrar texto em linhas | Lista separada por vírgula vinda de parâmetro de tela |
| Transformação em etapas (ETL) | Function que recebe um `SYS_REFCURSOR`, aplica regra por linha e devolve linhas novas, encadeável com outras |
| Expor resultado de lógica PL/SQL para SQL | Relatório que precisa de regra complexa, consultado por ferramenta que só fala SQL |

Para recebê-las, o parâmetro de cursor é passado com a expressão `CURSOR(SELECT ...)`:

```sql
SELECT * FROM TABLE(transformar(CURSOR(SELECT * FROM itens_pedido WHERE id_pedido = 1001)));
```

## Quando o consumidor para antes

Se a consulta busca só parte das linhas (`FETCH FIRST 5 ROWS ONLY`, `ROWNUM`), o próximo `PIPE ROW` levanta **NO_DATA_NEEDED**. Normalmente o Oracle trata em silêncio. Capture-a quando a function tiver algo a liberar (fechar cursor, gravar log); não a capture com `WHEN OTHERS` sem relançar outras exceções.

## Cuidados

- Function pipelined não pode fazer DML quando chamada por `SELECT`, a menos que use transação autônoma (tópico 12).
- O otimizador não sabe quantas linhas virão: estima um número fixo (costuma ser 8168 em bloco de 8 KB). Se o plano ficar ruim, informe com o hint `CARDINALITY` ou com a interface de extensão de estatísticas.
- `PARALLEL_ENABLE` com `PARTITION ... BY` permite execução paralela da function sobre o cursor de entrada.
- `[18c+]` **Polymorphic table functions** (PTF) generalizam a ideia: a estrutura das colunas devolvidas é definida na hora, a partir da tabela de entrada.

## Documentação oficial

- [PL/SQL Language Reference — Pipelined Table Functions](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/plsql-optimization-and-tuning.html)
- [PL/SQL Language Reference — PIPE ROW Statement](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/PIPE-ROW-statement.html)
