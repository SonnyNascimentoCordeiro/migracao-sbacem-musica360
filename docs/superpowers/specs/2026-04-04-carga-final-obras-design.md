# Design: Carga Final — obras.obra + obras.obra_integrante + pessoas.pessoa

**Data:** 2026-04-04
**Status:** Aprovado — aguardando implementação
**Fonte:** `mdb.sbacem` (302.585 linhas, 125.522 obras distintas)
**Destino:** tenant 38, configuração 61 (M360)

---

## Contexto

A migração SBACEM já possui o staging (`migracao_stg.sbacem_import_staging`) com links editoriais e cessão MR calculados. Esta spec define as regras para carga final nas tabelas de negócio do Woodstock: pessoas, obras, integrantes e a inserção do Musica 360 como sub-editor controlado.

---

## Regras de Negócio

### 1. Pessoas (`pessoas.pessoa`)

- Deduplica por `ipi_name_number` (chave única por tenant)
- `id_tenant = 38`
- `nome = UPPER(ip_name)`
- `ip_name = ipi_name_number`
- `ip_base = ipi_base_number`
- `tipo = 'F'` (padrão — não há distinção PF/PJ na fonte)
- `autor = true` se role em (CA, C, A, AR, SA, AD, TR)
- `editor = true` se role em (E, ES, AM, PA, SE, AQ)
- `importado = true`, `ativo = true`, `excluido = false`
- `codigo` = sequencial a partir do próximo disponível no tenant 38
- Referência cruzada: `pessoas.pessoa_de_para` com `ipi_name_number` como `codigo`

---

### 2. Obras (`obras.obra`)

- 1 registro por `atlas_id` distinto
- `id_tenant = 38`, `id_configuracao = 61`
- `titulo = original_title`
- `iswc` = valor da fonte (pode ser null)
- `situacao = 'L'` (liberada)
- `cod_tipo_versao = 'ORI'`
- `cancelada = false`, `retida = false`, `gravada = false`, `instrumental = false`
- `importado = true`, `nacional = true`
- `codigo` = sequencial a partir de 1 por tenant
- `controlada = true` se houver ao menos um integrante controlado pelo M360
- `controle_mr` = soma dos MR% do Musica 360 na obra
- `controle_pr = 0`, `controle_sr = 0`
- Referência cruzada: `obras.obra_de_para` com `atlas_id` como `codigo`

---

### 3. Links editoriais (`numero_link`)

- Pares autor+editor definidos pelo campo `chain` do editor apontando para o `chain_id` do autor
- Cada par recebe um `numero_link` sequencial dentro da obra (1, 2, 3...)
- Participantes **sem par** (chain=null sem editor correspondente) recebem link sequencial próprio
- Todos os participantes da obra têm `numero_link` preenchido

**Exemplo obra AW0MTYO2:**

| link | chain_id | participante | role |
|---|---|---|---|
| 1 | A | VINICIUS + BOCA (chain=A) | CA + E |
| 2 | B | ITALO + BOCA (chain=B) | CA + E |
| 3 | C | ALEX + BOCA (chain=C) | CA + E |
| 4 | D | IAASEN (sem editor) | CA |
| 5 | E | ENZO (sem editor) | CA |
| 6 | I | UNKNOWN PUBLISHER | E |
| 7 | J | UNKNOWN PUBLISHER | E |

---

### 4. Integrantes (`obras.obra_integrante`)

- 1 linha por participante por obra (sem colapsar duplicatas de IPI)
- `id_obra` = FK obra inserida
- `id_pessoa` = FK pessoa inserida (lookup por ipi_name_number no tenant 38)
- `cod_categoria = ip_role`
- `percentual_pr = per_own` (vírgula → ponto, cast float)
- `percentual_mr = mec_own` (idem) — **exceto titulares controlados** (ver regra M360)
- `percentual_sr = per_own` (mesmo que PR)
- `numero_link` = conforme regra de pares acima
- `controlado = true` se o participante é titular cedente (está em `mdb.titular` pelo `ipi_base_number`)
- `sequencia` = ordem da linha dentro da obra
- `criacao = now()`

---

### 5. Inserção do Musica 360 (`id_pessoa = 2405890`)

**Condição:** inserir o M360 para cada integrante que seja titular cedente (presente em `mdb.titular`).

**Regras:**

- **`percentual_mr`** do M360 = `MIN(percentual_mr_original_do_titular, percentual_cedido_tabela_titular)`
  - Se o titular tem MR menor que o % a ceder → M360 leva tudo, titular fica com 0
  - Se o titular tem MR maior → M360 leva o % indicado na tabela, titular é reduzido
- **`percentual_pr = 0`** sempre
- **`percentual_sr = 0`** sempre
- **`numero_link`** = mesmo link do titular cedente
- **`cod_categoria`:**
  - Se no mesmo link já existe outro integrante com role `E` → M360 entra como `SE`
  - Caso contrário → M360 entra como `E`
- **`controlado = true`** sempre para o M360
- O titular cedente tem `controlado = true` e seu `percentual_mr` reduzido pelo valor cedido ao M360

**Atualização em `obras.obra`:**
- `controlada = true`
- `controle_mr` = soma de todos os `percentual_mr` do M360 na obra
- `controle_pr = 0`
- `controle_sr = 0`

**Exemplo obra AW0MTYO2 — BOCA DO ORIENTE (titular, 15% a ceder, tem 6% MR):**

| link | nome | role | PR% | MR% | MR% original | controlado |
|---|---|---|---|---|---|---|
| 1 | VINICIUS... | CA | 14 | 14 | 14 | false |
| 1 | BOCA DO ORIENTE | E | 6 | **0** | 6 | true |
| 1 | MUSICA 360 | SE | 0 | **6** | — | true |
| 2 | ITALO... | CA | 14 | 14 | 14 | false |
| 2 | BOCA DO ORIENTE | E | 6 | **0** | 6 | true |
| 2 | MUSICA 360 | SE | 0 | **6** | — | true |
| 3 | ALEX... | CA | 14 | 14 | 14 | false |
| 3 | BOCA DO ORIENTE | E | 6 | **0** | 6 | true |
| 3 | MUSICA 360 | SE | 0 | **6** | — | true |
| 4 | IAASEN... | CA | 15 | 15 | 15 | false |
| 5 | ENZO... | CA | 15 | 15 | 15 | false |
| 6 | UNKNOWN PUBLISHER | E | 5 | 5 | 5 | false |
| 7 | UNKNOWN PUBLISHER | E | 5 | 5 | 5 | false |

`obras.obra`: `controlada=true`, `controle_mr=18` (6+6+6), `controle_pr=0`

---

## Títulos Alternativos (`obras.obra_titulo`)

- Inserir apenas quando `alternate_titles` não for null
- O campo `alternate_titles` pode conter múltiplos títulos separados por `|` — cada um vira 1 linha
- `cod_tipo_titulo = 'AL'`
- `ativo = true`
- `criacao = now()`

---

## Pessoas

**Não inserir pessoas.** As pessoas já existem no banco. O lookup de `id_pessoa` nos integrantes é feito via `pessoas.pessoa_de_para` pelo `ipi_name_number` no tenant 38.

---

## Sequência de Execução

1. Inserir obras (`obras.obra` + `obras.obra_de_para`)
2. Inserir títulos alternativos (`obras.obra_titulo`) quando houver
3. Inserir integrantes base da fonte (`obras.obra_integrante`)
4. Aplicar cessão MR: reduzir `percentual_mr` dos titulares cedentes
5. Inserir integrantes Musica 360 (`obras.obra_integrante`)
6. Atualizar `obras.obra` com `controlada`, `controle_mr`

---

## Restrições

- Nenhum dado de outros tenants deve ser alterado
- O script deve ser idempotente: usar rollback ou truncar staging antes de reexecutar
- Acesso ao banco é somente leitura via MCP — o SQL gerado é executado via psql/DBeaver
