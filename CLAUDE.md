# CLAUDE.md — Importação SBACEM → Woodstock (Tenant 38 - M360)

Contexto de importação de catálogo SBACEM para o banco de produção Woodstock.
Use este documento para dar continuidade ao trabalho em outra sessão.

---

## Conexões de Banco

| Ambiente | MCP Tool |
|---|---|
| Produção | `mcp__postgres-woodstock-prod__query` |
| Desenvolvimento | `mcp__postgres-woodstock-dev__query` |

Banco: `woodstock` | Usuário: `backstage`

---

## Contexto do Tenant de Destino

- **Tenant:** 38
- **Configuração:** 61
- **Referência:** M360
- **Editora padrão:** MUSICA 360 (id=2405890, codigo=2, id_tenant=38)
- **Situação atual:** 0 obras, 1 pessoa cadastrada (a própria editora)

---

## Fonte de Dados

**Schema/Tabela:** `mdb.sbacem` (banco de produção)

**Total de registros:** 302.585 linhas

**Estrutura:**

| Coluna | Tipo | Descrição |
|---|---|---|
| `atlas_id` | varchar | ID único da obra na fonte |
| `original_title` | varchar | Título original da obra |
| `alternate_titles` | varchar | Títulos alternativos (separados por `|`) |
| `iswc` | varchar | Código ISWC da obra |
| `work_codes` | varchar | Códigos cruzados da obra em outras fontes |
| `chain_id` | varchar | ID da cadeia |
| `chain` | varchar | Cadeia |
| `ip_name` | varchar | Nome do participante (Interested Party) |
| `ipi_name_number` | varchar | Número IPI do participante (chave de identificação) |
| `ipi_base_number` | varchar | Número base IPI do participante |
| `ip_internal_id` | varchar | ID interno do participante na fonte |
| `ip_role` | varchar | Papel do participante na obra (CA, E, C, A, etc.) |
| `per_own` | varchar | Percentual próprio de performance (ex: "100,00") |
| `per_soc` | varchar | Percentual sociedade de performance (ex: "NS (099)") |
| `mec_own` | varchar | Percentual próprio mecânico (ex: "0,00") |
| `mec_soc` | varchar | Percentual sociedade mecânico (ex: "SBACEM (066)") |
| `performers` | varchar | Intérpretes |
| `per_status` | varchar | Status performance (COMPLETE / INCOMPLETE) |
| `mec_status` | varchar | Status mecânico (COMPLETE / INCOMPLETE) |
| `source` | varchar | Fonte do registro |

**Volumes distintos:**

| Entidade | Qtd |
|---|---|
| Obras distintas (`atlas_id`) | 125.522 |
| Pessoas distintas (`ipi_name_number`) | 32.915 |
| Roles distintos (`ip_role`) | 13 |

**Distribuição de roles:**

| Role | Qtd | Descrição CWR |
|---|---|---|
| CA | 233.377 | Composer/Author |
| E | 59.677 | Editor |
| C | 4.595 | Composer |
| ES | 2.686 | Estranged sub-publisher |
| AM | 909 | Administrator |
| A | 685 | Author |
| AR | 220 | Arranger |
| SA | 218 | Sub-Author |
| AD | 146 | Adaptor |
| TR | 36 | Translator |
| PA | 17 | Publisher for agreement |
| SE | 11 | Sub-editor |
| AQ | 8 | Acquirer |

---

## Tabelas de Destino

### `pessoas.pessoa`
Colunas relevantes: `id`, `id_tenant`, `codigo`, `nome`, `tipo`, `autor`, `editor`, `ip_name`, `ip_base`, `ativo`, `importado`, `excluido`

### `obras.obra`
Colunas relevantes: `id`, `id_tenant`, `id_configuracao`, `codigo`, `titulo`, `iswc`, `situacao`, `cod_tipo_versao`, `cancelada`, `retida`, `gravada`, `instrumental`, `controlada`, `controle_pr`, `controle_mr`, `controle_sr`, `importado`, `nacional`, `criacao`

### `obras.obra_titulo`
Colunas: `id`, `id_obra`, `titulo`, `cod_tipo_titulo`, `cod_idioma`, `ativo`, `criacao`

### `obras.obra_integrante`
Colunas relevantes: `id`, `id_obra`, `id_pessoa`, `cod_categoria`, `controlado`, `percentual_pr`, `percentual_mr`, `percentual_sr`, `percentual_base`, `sequencia`, `criacao`

### `obras.obra_de_para`
Colunas: `id`, `id_obra`, `id_parceiro`, `codigo`, `criacao`
> Usar para guardar o `atlas_id` original como referência cruzada.

### `pessoas.pessoa_de_para`
Colunas: `id`, `id_pessoa`, `id_parceiro`, `codigo`, `criacao`
> Usar para guardar o `ipi_name_number` original como referência cruzada.

---

## Mapeamento Fonte → Destino

### Pessoa (`pessoas.pessoa`)

| Campo destino | Valor |
|---|---|
| `id_tenant` | 38 |
| `nome` | `ip_name` (uppercase) |
| `ip_name` | `ipi_name_number` |
| `ip_base` | `ipi_base_number` |
| `tipo` | `'F'` (padrão - verificar se há editoras) |
| `autor` | `true` se role em (CA, C, A, AR, SA, AD, TR) |
| `editor` | `true` se role em (E, ES, AM, PA, SE, AQ) |
| `importado` | `true` |
| `ativo` | `true` |
| `excluido` | `false` |
| `codigo` | sequencial a partir do próximo disponível |

### Obra (`obras.obra`)

| Campo destino | Valor |
|---|---|
| `id_tenant` | 38 |
| `id_configuracao` | 61 |
| `titulo` | `original_title` |
| `iswc` | `iswc` |
| `situacao` | `'L'` (liberada) |
| `cod_tipo_versao` | `'ORI'` |
| `cancelada` | `false` |
| `retida` | `false` |
| `gravada` | `false` |
| `instrumental` | `false` |
| `importado` | `true` |
| `criacao` | `now()` |
| `codigo` | sequencial a partir de 1 |

### Integrante de Obra (`obras.obra_integrante`)

| Campo destino | Valor |
|---|---|
| `id_obra` | FK → obra inserida |
| `id_pessoa` | FK → pessoa inserida |
| `cod_categoria` | `ip_role` |
| `percentual_pr` | `per_own` (converter vírgula → ponto, cast float) |
| `percentual_mr` | `mec_own` (converter vírgula → ponto, cast float) |
| `percentual_sr` | `per_own` (mesmo valor que PR por padrão) |
| `controlado` | `false` (padrão, a menos que seja a própria editora M360) |
| `sequencia` | ordem da linha dentro da obra |
| `criacao` | `now()` |

---

## Questões em Aberto (PENDENTES DE RESPOSTA)

1. **Códigos de obras** — usar sequencial numérico simples a partir de 1? Ou há um padrão específico para o M360?

2. **`controlada` na obra** — quando marcar a obra como controlada? Quando a editora MUSICA 360 (id=2405890) estiver entre os integrantes?

3. **`alternate_titles`** — importar para `obras.obra_titulo`? Qual `cod_tipo_titulo` usar?

4. **Pessoas por tenant** — criar pessoas novas com `id_tenant=38` para cada IP (mesmo que já exista o mesmo IPI em outro tenant), ou reutilizar IDs existentes?

5. **`nacional`** — as obras entram como nacionais (`true`) ou não (`false`)? A fonte é SBACEM (brasileira), mas pode conter obras estrangeiras.

6. **`tipo` da pessoa** — como distinguir pessoa física (F) de jurídica (J) para os IPs? Usar `ipi_base_number` como critério?

7. **Percentual SR** — usar o mesmo valor de `per_own` ou deixar nulo?

---

## Observações Importantes

- A importação é **exclusivamente** para `id_tenant=38` e `id_configuracao=61`. Nenhum dado deve ser inserido com outro tenant.
- Os percentuais na fonte usam **vírgula como separador decimal** (ex: `"100,00"`). Converter com `REPLACE(campo, ',', '.')::float`.
- O campo `ipi_name_number` é a **chave de deduplicação** de pessoas.
- O campo `atlas_id` é a **chave de deduplicação** de obras.
- O acesso ao banco é **somente leitura via MCP**. O script de importação deve ser gerado como SQL e executado por fora (via psql ou DBeaver).
- Nunca alterar dados de outros tenants.
