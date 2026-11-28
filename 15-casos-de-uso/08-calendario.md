# Calendário e dias sem movimento

## Cenário

Relatórios diários, semanais e de prazo precisam de **todos os dias**, não só dos que têm registro: o gráfico diário de vendas de outubro/2026 tem 31 pontos, mas só dois dias tiveram pedido (14 e 30). Prazos de entrega contam **dias úteis**, pulando fim de semana e feriado.

A solução é ter um calendário (gerado na hora ou numa tabela) e partir dele com `LEFT JOIN`.

## Gerar os dias

| Forma | Observação |
|---|---|
| `SELECT DATE '2026-10-01' + LEVEL - 1 FROM dual CONNECT BY LEVEL <= 31` | A mais usada. Sempre sobre `DUAL` (uma linha): sobre uma tabela de N linhas, `CONNECT BY LEVEL` sem `PRIOR` multiplica as linhas |
| CTE recursiva `[11gR2+]` | Padrão SQL, a mesma escrita do PostgreSQL e do SQL Server |
| Tabela de calendário | Gerada uma vez, com colunas prontas (ano, mês, dia da semana, útil, feriado). É a dimensão de tempo do data warehouse (seção 14, tópico 04) |

Para o mês inteiro sem contar dias: `CONNECT BY LEVEL <= LAST_DAY(:inicio) - :inicio + 1`.

## Dia da semana sem depender de NLS

`TO_CHAR(d, 'D')` devolve o número do dia conforme `NLS_TERRITORY`: domingo é 1 no Brasil e nos EUA, segunda é 1 em boa parte da Europa. Para uma regra que não muda com a sessão:

```sql
dia - TRUNC(dia, 'IW')     -- 0 = segunda ... 6 = domingo (semana ISO começa na segunda)
```

Para o nome, fixe o idioma na chamada: `TO_CHAR(dia, 'DY', 'NLS_DATE_LANGUAGE=PORTUGUESE')`.

## Dias úteis

Útil = não é sábado nem domingo e não está na tabela de feriados. O Oracle não tem calendário de feriados embutido; a tabela é do sistema (nacionais, estaduais e municipais, conforme a necessidade).

- **Contar dias úteis entre duas datas**: `COUNT(*)` sobre o calendário filtrado.
- **Somar N dias úteis** a uma data: numerar os dias úteis depois da data com `ROW_NUMBER` e pegar o N-ésimo.

Nos dois casos, a tabela de feriados deve ter a data `NOT NULL`, porque a filtragem usa `NOT IN` (caso 05).

## Resultados de referência (outubro e novembro de 2026)

| | Outubro | Novembro |
|---|---|---|
| Dias | 31 | 30 |
| Sábados e domingos | 9 | 9 |
| Feriados em dia de semana | 12/10 (segunda) | 02/11 (segunda), 20/11 (sexta); 15/11 cai no domingo |
| Dias úteis | 21 | 19 |

Pedido 1023 (14/10) + 5 dias úteis = 21/10. Pedido 1024 (30/10, sexta) + 5 dias úteis = 09/11, porque 02/11 é feriado.

## Documentação oficial

- [SQL Language Reference — Hierarchical Queries](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Hierarchical-Queries.html)
- [SQL Language Reference — Datetime Format Models](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Format-Models.html)
