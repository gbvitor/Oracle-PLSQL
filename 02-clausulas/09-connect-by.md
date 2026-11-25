# CONNECT BY (consultas hierárquicas)

## O que faz

Percorre dados em árvore guardados com auto-relacionamento (cada linha aponta para a "mãe"): organograma, árvore de categorias, estrutura de produto, plano de contas. É sintaxe própria do Oracle, existente muito antes do `WITH` recursivo, e ainda a mais usada em código Oracle.

```sql
-- START WITH: por onde começar (as raízes)
-- CONNECT BY: como ir de uma linha para a próxima
SELECT LEVEL, nome
  FROM funcionarios
 START WITH id_gerente IS NULL
CONNECT BY PRIOR id_funcionario = id_gerente;
```

## As partes

| Parte | Papel |
|---|---|
| `START WITH condição` | Define as linhas raiz. Sem ela, **toda** linha vira raiz de uma árvore própria |
| `CONNECT BY condição` | Liga a linha atual às filhas. `PRIOR` marca a coluna da linha já percorrida (a mãe) |
| `PRIOR` | Do lado da mãe: `PRIOR id_funcionario = id_gerente` lê "o id da mãe é o gerente da filha" |
| `NOCYCLE` | `CONNECT BY NOCYCLE ...` não para com erro em ciclo; usa `CONNECT_BY_ISCYCLE` para marcar |
| `ORDER SIBLINGS BY` | Ordena irmãos sem desmontar a árvore |

## Direção

A posição do `PRIOR` define o sentido:

```sql
-- De cima para baixo: dos gerentes para os subordinados
CONNECT BY PRIOR id_funcionario = id_gerente

-- De baixo para cima: do funcionário até a diretoria
START WITH id_funcionario = 104
CONNECT BY id_funcionario = PRIOR id_gerente
```

## Pseudocolunas e funções

| Item | Devolve |
|---|---|
| `LEVEL` | Profundidade: 1 na raiz |
| `SYS_CONNECT_BY_PATH(coluna, '/')` | Caminho da raiz até a linha |
| `CONNECT_BY_ROOT coluna` | Valor da coluna na raiz da árvore da linha |
| `CONNECT_BY_ISLEAF` | 1 se a linha não tem filhas |
| `CONNECT_BY_ISCYCLE` | 1 se a linha fecha um ciclo (exige `NOCYCLE`) |

`CONNECT_BY_ROOT` resolve um problema comum: "total de subordinados de cada gerente em todos os níveis". Sem `START WITH`, cada funcionário é raiz da própria árvore; agrupando por `CONNECT_BY_ROOT`, conta-se tudo o que está abaixo de cada um.

## Onde vai o filtro

A ordem de avaliação numa consulta hierárquica é: joins, depois `START WITH`/`CONNECT BY`, depois o restante do `WHERE`.

- Condição no **`WHERE`**: tira a linha do resultado, mas os filhos dela continuam aparecendo.
- Condição no **`CONNECT BY`**: interrompe o percurso naquela linha; ela e todos os descendentes somem.

## CONNECT BY como gerador

```sql
SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 10;
```

Sem relação mãe e filha, a condição `LEVEL <= 10` só limita a profundidade, e `DUAL` tem uma linha: o resultado é uma sequência de 1 a 10. Muito usado para gerar datas e números. Em tabela com mais de uma linha, o mesmo truque explode combinatoriamente.

## CONNECT BY ou WITH recursivo

| | `CONNECT BY` | `WITH` recursivo |
|---|---|---|
| Portabilidade | Só Oracle | Padrão SQL (PostgreSQL, SQL Server...) |
| Escrita | Mais curta | Mais longa |
| Caminho, raiz, folha | Prontos (`SYS_CONNECT_BY_PATH`, `CONNECT_BY_ROOT`, `CONNECT_BY_ISLEAF`) | Calculados à mão |
| Cálculo acumulado ao descer (custo × quantidade numa estrutura de produto) | Difícil | Natural |

## Armadilhas

- **Esquecer o `START WITH`.** Cada linha vira raiz, e o resultado repete subárvores.
- **`ORDER BY` comum** desfaz a árvore; use `ORDER SIBLINGS BY`.
- **Ciclo nos dados** dá ORA-01436. Use `NOCYCLE` para achar onde está.
- **`PRIOR` do lado errado** inverte a direção sem erro.

## Documentação oficial

- [SQL Language Reference — Hierarchical Queries](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Hierarchical-Queries.html)
