# Data model — Importação com link numérico, titular e M360

**Specs de referência**: `specs/001-import-obras-mdb-titular/spec.md`, `specs/002-chain-link-numeric/spec.md`  
**Constituição**: `.specify/memory/constitution.md`

## Fonte (read-only / staging)

| Origem | Grão | Chaves / notas |
|--------|------|----------------|
| `mdb.sbacem` | 1 linha = participante na obra | `atlas_id` (obra), `chain_id`, `chain`, `ip_role`, percentuais texto |
| `mdb.titular` | CAE + cessão MR | join típico: `cae` = `ipi_name_number` da `sbacem` |
| `mdb.titular2` | idem | mesma semântica que `titular` quando CAE duplicado (**FR-008**) |

## Destino (tenant 38, config 61)

### `obras.obra`

| Campo | Regra |
|-------|--------|
| `id_tenant` | **38** (obrigatório) |
| `id_configuracao` | **61** |
| `codigo` | `atlas_id` (ou política já acordada) |
| `titulo` | `original_title` |
| `iswc` | `iswc` |
| `controlada` | **true** se houver linha(s) M360 por cessão (**FR-004**) |
| `controle_mr` | soma **MR** das participações **Música 360** |
| `controle_pr` / `controle_sr` | **0** no desenho atual da spec **001** (rever se produto exigir) |
| `importado` | **true** |
| Demais flags | conforme **001** (`situacao`, `cod_tipo_versao`, etc.) |

### `obras.obra_integrante`

| Campo | Regra |
|-------|--------|
| `id_obra` | FK obra criada |
| `id_pessoa` | FK `pessoas.pessoa` (MUSICA 360 / participantes dedup por IPI) |
| `cod_categoria` | mapa `ip_role` → CWR; M360 → **SE** se **E** no mesmo link, senão **E** (**FR-010**) |
| `percentual_pr`, `percentual_mr`, `percentual_sr` | `sbacem` + cessão só em MR; SR espelha PR por linha (padrão legado) |
| `controlado` | false salvo regra editora M360 |
| `sequencia` | ordem de exibição; **não** define víncio editorial (**FR-003**) |
| **`link` (ou equivalente)** | inteiro por grupo; **mesmo valor** para titular + editora(s) do par + M360 do titular controlado — **persistir conforme DDL** (ver `research.md`) |

### Rastreabilidade

| Tabela | Uso |
|--------|-----|
| `obras.obra_de_para` | `atlas_id` |
| `pessoas.pessoa_de_para` | `ipi_name_number` |

## Relacionamentos (lógicos)

```text
obra (1) ──< obra_integrante (N) >── pessoa (1)
obra (1) ──< obra_de_para (N)
pessoa (1) ──< pessoa_de_para (N)
```

## Validações obrigatórias

1. Por obra: **Σ PR = Σ MR = Σ SR = 100%** (tolerância de arredondamento documentada).
2. **Cessão ≤ MR agregado** do cedente; senão exceção (**FR-008**).
3. Todo `chain` não vazio referencia `chain_id` existente na mesma obra (**FR-009**).
4. Nenhum INSERT fora de `id_tenant = 38`.

## Estado / fases sugeridas (materialização)

| Fase | Conteúdo |
|------|----------|
| Staging | rows enriquecidas: `atlas_id`, `chain_id`, `chain`, `link`, papéis, % calculados |
| Validação | relatório de erros (chain quebrado, cessão, somas) |
| Load | INSERT pessoa → obra → integrante → de_para |
