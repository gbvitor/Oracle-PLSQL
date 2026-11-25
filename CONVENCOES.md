# Convenções

## Organização

Cada seção é uma pasta numerada com um `README.md` que funciona como índice da seção. Cada tópico dentro dela tem um arquivo `.md` com a explicação e um ou mais scripts `.sql` com o mesmo prefixo numérico:

```
02-clausulas/
├── README.md                  índice da seção
├── 01-select-distinct.md      explicação
├── 01-select-distinct.sql     exemplos executáveis
├── 02-where.md
├── 02-where.sql
└── ...
```

Tópicos curtos podem ficar só no `.md`, com os exemplos em blocos de código. Quando o exemplo for para rodar, ele vai para o `.sql`.

## Estrutura de um tópico (.md)

1. **O que é** — definição curta, em linguagem direta.
2. **Sintaxe** — forma geral, com as partes opcionais entre colchetes.
3. **Exemplos** — do mais simples ao mais completo, sempre sobre o schema de exemplo.
4. **Quando usar e quando evitar** — critério prático de escolha.
5. **Armadilhas** — comportamentos que surpreendem (NULL, conversão implícita, ordem de avaliação etc.).
6. **Versão** — a partir de qual versão existe, quando não for 19c.
7. **Documentação oficial** — link para o capítulo correspondente.

Nem todo tópico precisa de todas as partes; seções vazias são omitidas.

## Padrão dos scripts (.sql)

- Cabeçalho com tópico, objetivo e versão mínima.
- Cada script roda sozinho sobre o schema de exemplo, sem depender de outro script além da carga inicial.
- Script que cria objetos ou altera dados termina com o bloco de limpeza (`ROLLBACK` ou `DROP`), para o schema voltar ao estado original.
- Palavras-chave em maiúsculas, nomes de objetos em minúsculas.
- Comentário antes de cada consulta dizendo o que ela demonstra e, quando útil, o resultado esperado (`-- Esperado: ...`). Nunca comentário depois do `;` na mesma linha, nem `&` dentro de comentário (ver `01-fundamentos/08-comentarios.md`).

Cabeçalho padrão:

```sql
-- =============================================================================
-- Tópico : WHERE — filtros básicos
-- Seção  : 02-clausulas
-- Versão : 19c
-- Requer : schema de exemplo (00-ambiente)
-- =============================================================================
```

## Marcação de versão

| Marca | Significado |
|---|---|
| (nenhuma) | Funciona no 19c |
| `[21c+]` | Exige 21c ou superior |
| `[23ai+]` | Exige 23ai ou superior (inclui 26ai) |
| `[legado]` | Sintaxe antiga, mantida para leitura de código existente; não usar em código novo |

## Nomenclatura

- Pastas e arquivos: minúsculas, sem acento, palavras separadas por hífen.
- Objetos de banco nos exemplos: português, minúsculas, `snake_case`, sem acento.
- Objetos criados só para um exemplo usam o prefixo `tmp_` e são removidos no fim do script.

## Conteúdo

Repositório público. Todos os dados são fictícios; nenhum exemplo usa estrutura, nome de tabela ou dado de sistema real de empresa.
