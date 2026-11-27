# Constraints

## Tipos

| Tipo | Sigla no dicionário | Garante | Cria índice |
|---|---|---|---|
| `NOT NULL` | C | A coluna tem valor | Não |
| `PRIMARY KEY` | P | Unicidade e ausência de NULL; uma por tabela | Sim (único), se não houver um utilizável |
| `UNIQUE` | U | Unicidade (aceita vários NULLs) | Sim (único), se não houver um utilizável |
| `FOREIGN KEY` | R | O valor existe na tabela referenciada (ou é NULL) | **Não** |
| `CHECK` | C | Uma condição sobre a própria linha | Não |

## Sintaxe

```sql
-- Inline, junto da coluna
id_cliente NUMBER CONSTRAINT pk_clientes PRIMARY KEY,

-- Out-of-line, depois das colunas (obrigatório para constraint de várias colunas)
CONSTRAINT pk_itens_pedido PRIMARY KEY (id_pedido, nr_item),
CONSTRAINT fk_itens_pedido FOREIGN KEY (id_pedido) REFERENCES pedidos (id_pedido),

-- Depois de criada a tabela
ALTER TABLE t ADD CONSTRAINT ck_t_valor CHECK (valor >= 0);
ALTER TABLE t DROP CONSTRAINT ck_t_valor;
ALTER TABLE t RENAME CONSTRAINT antigo TO novo;
```

**Sempre dê nome.** Sem nome, o Oracle gera `SYS_C0012345`, que muda de ambiente para ambiente e não diz nada na mensagem de erro.

## Chave estrangeira: o que acontece ao apagar a linha pai

| Opção | Ao apagar o pai |
|---|---|
| (padrão) | Recusa se houver filhos (ORA-02292) |
| `ON DELETE CASCADE` | Apaga os filhos junto |
| `ON DELETE SET NULL` | Põe NULL na FK dos filhos (a coluna precisa aceitar NULL) |

Não existe `ON UPDATE CASCADE` no Oracle: chave primária não deve mudar.

`ON DELETE CASCADE` é adequado para dependência de composição (itens de um pedido); é perigoso entre entidades independentes (pedidos de um cliente), onde um `DELETE` errado apaga histórico em cascata.

**Crie um índice na coluna da FK** (seção 06, tópico 08).

## CHECK

- Só pode usar colunas **da própria linha**: não aceita subquery, `SYSDATE`, sequence nem função definida pelo usuário (para regras que dependem de outras linhas ou da data atual, trigger ou lógica na aplicação).
- Passa quando o resultado é TRUE **ou UNKNOWN**: `CHECK (valor > 0)` aceita NULL.
- Pode comparar colunas entre si: `CHECK (data_fim >= data_inicio)`.

## Constraint versus índice único

Uma `PRIMARY KEY` ou `UNIQUE` usa um índice para verificar a unicidade. Se já existir um índice (único ou não) com as mesmas colunas no início, o Oracle o reaproveita. Ao apagar a constraint, o índice criado por ela é apagado junto; um índice que já existia antes fica (`DROP CONSTRAINT ... KEEP INDEX` / `DROP INDEX` controlam isso).

## Documentação oficial

- [SQL Language Reference — constraint](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/constraint.html)
