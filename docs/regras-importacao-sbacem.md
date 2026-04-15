# Regras de Importação SBACEM → Woodstock (Tenant 38 / M360)

**Tenant:** 38 | **Configuração:** 61 | **Musica 360:** id_pessoa=2405890

---

## 1. Obras (`obras.obra`)

| Campo | Valor |
|---|---|
| `id_tenant` | 38 |
| `id_configuracao` | 61 |
| `codigo` | `atlas_id` (chave de lookup) |
| `titulo` | `original_title` |
| `iswc` | `iswc` (null se vazio) |
| `situacao` | `'L'` |
| `cod_tipo_versao` | `'ORI'` |
| `cancelada` | `false` |
| `retida` | `false` |
| `gravada` | `false` |
| `instrumental` | `false` |
| `importado` | `true` |
| `nacional` | `true` |
| `registro` | `CURRENT_DATE` |
| `controlada` | `true` se há M360 na obra |
| `controle_pr` | `0` |
| `controle_mr` | soma `coleta_mr` do M360 |
| `controle_sr` | soma `coleta_sr` do M360 |

---

## 2. Títulos Alternativos (`obras.obra_titulo`)

- Inserir apenas `alternate_titles` (não o título principal)
- Separador `|` — cada parte vira 1 linha
- `cod_tipo_titulo = 'AL'`
- `ativo = true`

---

## 3. Links Editoriais (`link` em `obra_integrante`)

- Editor tem campo `chain` apontando para `chain_id` do(s) autor(es)
- `chain` pode ter múltiplos valores separados por ` | ` (ex: `"E | F"`)
- Cada par autor+editor recebe um `link` sequencial único por obra
- Editor com `chain = "E | F"` gera **duas linhas** — uma por alvo (link 2 com JOAO, link 3 com ROBESON)
- Participantes sem par recebem link sequencial próprio (após os pares)
- **Todos** os participantes têm link preenchido

---

## 4. Integrantes Base (`obras.obra_integrante`)

### Lookup de pessoa
```
pessoas.pessoa.ip_name = mdb.sbacem.ipi_name_number AND id_tenant = 38
```

### Campos fixos
- `cod_territorio = '76'` (Brasil)

### Percentuais de propriedade
| Campo | Valor |
|---|---|
| `percentual_pr` | `per_own` |
| `percentual_mr` | Ver regra abaixo |
| `percentual_sr` | `= percentual_mr` |
| `percentual_base` | `per_own` |

### Regra do `percentual_mr`
- **Não controlado:** `percentual_mr = mec_own`
- **Titular cedente:** `percentual_mr = GREATEST(0, mec_own - LEAST(mec_own, pct_cessao))` com `pct_cessao` = `titular2.percentual` se preenchido, senão `titular.percentual`

### Percentuais de coleta
| Campo | Controlado | Não controlado |
|---|---|---|
| `coleta_pr` | `per_own` | `per_own` |
| `coleta_mr` | `0` | `0` |
| `coleta_sr` | `0` | `0` |

### Controlado
- `controlado = true` se o participante está em `mdb.titular` **ou** em `mdb.titular2`
- Lookup: `mdb.titular.ipi = mdb.sbacem.ipi_base_number` e/ou `mdb.titular2.ipi` (LIMIT 1 em cada)

---

## 5. Titular Cedente (`mdb.titular` / `mdb.titular2`)

- `mdb.titular.ipi` ou `mdb.titular2.ipi = mdb.sbacem.ipi_base_number` (LIMIT 1 em cada)
- Campo `percentual` é numérico (ex: `"15"` — `%` opcional)
- Para **cessão MR** na importação Java: se `titular2.percentual` estiver preenchido, usa-se ele; senão `titular.percentual`
- MR cedido ao M360: `LEAST(mec_own, pct_cessao)`
- MR que sobra ao titular: `GREATEST(0, mec_own - LEAST(mec_own, pct_cessao))`
- Se `mec_own < pct_cessao` → titular fica com 0%, M360 leva tudo que tinha

---

## 6. Musica 360 (`id_pessoa = 2405890`)

### Inserção
- Inserido **uma vez por link** onde há titular cedente
- Nunca inserido mais de uma vez no mesmo link

### Categoria (`cod_categoria`)
- `'AM'` se já existe `E` no mesmo link
- `'E'` caso contrário

### Percentuais de propriedade
| Campo | Valor |
|---|---|
| `percentual_pr` | `0` |
| `percentual_mr` | `LEAST(mec_own, pct_cessao)` com `pct_cessao` = `titular2.percentual` se informado, senão `titular.percentual` (soma se múltiplos cedentes no link) |
| `percentual_sr` | `= percentual_mr` |
| `percentual_base` | `0` |

### Percentuais de coleta
| Campo | Valor |
|---|---|
| `coleta_pr` | `0` (sempre) |
| `coleta_mr` | soma `coleta_pr` dos controlados do **mesmo link** |
| `coleta_sr` | `= coleta_mr` |

### Outros
- `controlado = true` sempre
- `cod_territorio = '76'`

---

## 7. Percentuais de Distribuição (fonomecanico + sincronizacao)

> Refletem a **distribuição** de direitos (separado de `percentual_*` / cessão **MR** da spec 001).  
> **`sincronizacao` = `fonomecanico`** (mesmo valor nos dois campos).

### Escopo: sempre por `link`

- Cada `numero_link` / `link` é um grupo editorial próprio.
- Não se modela obra válida **sem** autor ou editora **controlada** no fluxo de negócio.
- Não controlados: `fonomecanico = sincronizacao = 0`.

### `mdb.titular` vs `mdb.titular2`

- **`mdb.titular`**: titulares **pessoa física** (PF).
- **`mdb.titular2`**: titulares **pessoa jurídica** (PJ).
- Na prática da importação Java: `pessoas.pessoa.tipo` (`F` / `J`) define o eixo do contrato na distribuição: **autor PF** usa **15%** fixo; **autor PJ** usa `mdb.titular2.percentual`; **editora PF** usa `mdb.titular.percentual` (pessoa física também pode ser editora titular); **editora PJ** usa `mdb.titular2.percentual`. Se o percentual de contrato da editora PF não existir em `titular`, cai no **15%** como fallback.

### Papéis (SBACEM `ip_role` → `cod_categoria`)

- **Autor** (15% ou contrato PJ): `CA`, `C`, `A`, `AR`, `SA`, `AD`, `TR`.
- **Editora / administrador editorial** (`titular` PF ou `titular2` PJ): `E`, `ES`, `AM`, `PA`, `SE`, `AQ`.
- Outros papéis controlados: `fonomecanico = sincronizacao = 0` na distribuição.

### Fórmulas (base = `percentual_base` = `per_own` da linha naquele `link`)

**Autor controlado, PF (`tipo = F` ou ausente):**

- Parcela para M360: `ROUND(base * 0.15, 2)`
- `fonomecanico = sincronizacao = ROUND(base - parcela_m360, 2)` (mínimo 0)

**Autor controlado, PJ:**

- `pct = percentual` numérico de `mdb.titular2` para o `ipi_base_number` da linha (`%` opcional no texto).
- Parcela M360: `ROUND(base * pct / 100, 2)`
- Remanescente: `ROUND(base - parcela, 2)`

**Editora controlada, PF:**

- `pct = percentual` em `mdb.titular` (IPI base da linha). Se `pct <= 0`, usar **15%** (igual autor PF).
- Parcela M360: `ROUND(base * pct / 100, 2)` com `pct` já em escala 0–100.

**Editora controlada, PJ:**

- Parcela M360: `ROUND(base * pct_titular2 / 100, 2)` com `pct` vindo de `mdb.titular2`.

### Linha Música 360 (`id_pessoa = 2405890`)

Por **link** onde há integrantes controlados com parcela:

```
fonomecanico = sincronizacao = SUM(parcelas_m360 dos integrantes controlados daquele link)
```

(arredondamento por linha antes da soma; ver testes em `IntegranteBuilderServiceTest`.)

### M360 já existente na obra (reimportação)

- Se `obras.obra.codigo = atlas_id` já existir e `obra_integrante` já tiver **Música 360** (`id_pessoa = 2405890`) naquele **`link`**, a importação **não grava** nova linha M360 nesse link (`omitir_insercao` no modelo Java); o cálculo de distribuição em memória **mantém** uma linha M360 lógica para fechar `fonomecanico` / `sincronizacao`.
- **Atenção:** reimportar com obra já existente **reinsere** os demais integrantes se o fluxo inserir de novo — limpeza de `obra_integrante` antes da carga é responsabilidade do operador, salvo evolução futura de upsert.

### Exemplos

1. **Um autor controlado PF**, `base = 100` no link: autor `85`, M360 `15`.
2. **Dois autores PF** no mesmo link, `50` + `50`: cada autor `42,5`; M360 `7,5 + 7,5 = 15`.
3. **Uma editora PJ** no link, `base = 10`, contrato `titular2 = 60%`: editora `4`, M360 `6`.

### Cessão MR (fase 1) e `titular` / `titular2`

- Percentual de **cessão mecânica** (MR) segue prioridade **`titular2`** quando o campo `percentual` está preenchido; senão **`titular`** (alinhado a `fase3_query4_ajuste_mr_sr.sql`).

### execucao_publica

- `0` para todos (M360 não participa de execução pública).

---

## 8. Controle da Obra

Após inserir todos os integrantes:

```
obras.obra.controlada  = true  (se há M360)
obras.obra.controle_mr = SUM(coleta_mr) WHERE id_pessoa = 2405890
obras.obra.controle_sr = SUM(coleta_sr) WHERE id_pessoa = 2405890
```

---

## 9. Fontes de Dados

| Tabela | Uso |
|---|---|
| `mdb.sbacem` | Fonte principal — obras e participantes |
| `mdb.titular` | Titulares cedentes (autores/editores controlados pelo M360) |
| `mdb.titular2` | Editoras administradas pelo M360 (para distribuição proporcional) |
| `pessoas.pessoa` | Lookup de id_pessoa por ip_name (id_tenant=38) |

---

## 10. Regras de Segurança

- **Somente tenant 38** — nunca inserir em outro tenant
- **Não usar `obra_de_para` nem `pessoa_de_para`** — lookup direto pelas tabelas
- **Limpeza manual** — executar SQL de limpeza antes de reimportar (não automático)

---

## 11. Script e Procedure Legados

- Procedure: `mdb.carga_final_obras()` (SQL puro, substituída pelo programa Java)
- Script: `scripts/migracao/sql/carga_final_obras.sql`
- Programa Java: `scripts/importacao/` (Spring Boot + JDBI)

---

## 12. Modos de Execução (programa Java)

```bash
# Preview sem inserir no banco
GET http://localhost:8090/importacao/preview/{atlas_id}

# Importar obra específica
POST http://localhost:8090/importacao/obra/{atlas_id}

# Importar todas as obras
POST http://localhost:8090/importacao/todas

# Interface visual
http://localhost:8090/index.html
```
