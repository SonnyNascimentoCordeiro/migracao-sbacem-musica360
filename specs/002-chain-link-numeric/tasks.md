# Tasks: Importação MDB — link numérico, cessão e Música 360

**Input**: `specs/002-chain-link-numeric/` (plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md)  
**Prerequisites**: plan.md, spec.md  
**Tests**: não solicitados na spec — validação por **SQL de conferência** e obra `AW0MTYO2`.

**Prioridade de negócio (spec)**: US1 P1, US2 P1, US4 P1, US3 P2.  
**Ordem técnica recomendada nesta lista**: após **US1**, executar **US3** (fallback de `chain` vazio) antes de **US2**/**US4**, para que links e relatórios estejam completos na carga.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependência de tarefa incompleta)
- **[USn]**: User Story da `specs/002-chain-link-numeric/spec.md`

---

## Phase 1: Setup (infraestrutura compartilhada)

**Purpose**: estrutura de pastas, configuração e rastreio alinhados ao `plan.md`.

- [X] T001 Criar diretório `scripts/migracao/` e `scripts/migracao/README.md` com visão geral do pipeline, aviso de tenant **38** e ordem de execução dos `.sql`/`.py`
- [X] T002 [P] Criar `scripts/migracao/.env.example` com placeholders `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `ID_PESSOA_M360`, `ID_PARCEIRO_DE_PARA`
- [X] T003 [P] Criar `scripts/migracao/reports/.gitkeep` para CSVs de exceção (`CHAIN_DANGLING`, fallback `chain` vazio, etc.)

---

## Phase 2: Foundational (bloqueia todas as user stories)

**Purpose**: DDL/staging, normalização, mapa de papéis e visão unificada de cessão (**FR-008** / spec **001**).

**Checkpoint**: staging populável a partir de `mdb.sbacem`; titular unificado consultável.

- [X] T004 Criar `scripts/migracao/ddl/verify_obra_integrante_link.sql` consultando `information_schema` para confirmar coluna de **link** (ou documentar decisão alternativa em `specs/002-chain-link-numeric/research.md`)
- [X] T005 Criar `scripts/migracao/staging/01_staging_tables.sql` com tabelas staging por obra/linha (`atlas_id`, `chain_id`, `chain`, `ip_role`, percentuais normalizados, `link` futuro, metadados)
- [X] T006 Criar `scripts/migracao/sql/populate_staging_from_sbacem.sql` (INSERT…SELECT de `mdb.sbacem` para staging) aplicando `REPLACE(per_own, ',', '.')::double precision` e equivalentes para MR (**constituição**)
- [X] T007 [P] Criar `scripts/migracao/doc/role_map_sbacem_to_categoria.md` com mapa `ip_role` → `cod_categoria` alinhado a `CLAUDE.md` e specs **001**/**002**
- [X] T008 Criar `scripts/migracao/sql/titular_cessao_unificada.sql` (CTE/view) unindo `mdb.titular` e `mdb.titular2` por CAE com **uma** cessão por CAE (**FR-008**)
- [X] T009 Criar esqueleto `scripts/migracao/sql/02_load_pessoas_dedup.sql` deduplicando por `ipi_name_number`, `id_tenant=38`, `importado=true` (spec **001** / `data-model.md`)
- [X] T010 Criar esqueleto `scripts/migracao/sql/03_load_obras.sql` inserindo `obras.obra` com `id_configuracao=61`, `codigo=atlas_id`, flags da spec **001** (sem M360 ainda)
- [X] T011 Criar esqueleto `scripts/migracao/sql/04_load_integrantes_sbacem_base.sql` inserindo integrantes a partir do staging **antes** das linhas M360 (percentuais PR/MR/SR por linha fonte, `sequencia` apenas ordenação)

---

## Phase 3: User Story 1 — Par titular–editora com mesmo link (Priority: P1)

**Goal**: resolver `chain` → `chain_id` do titular e atribuir **mesmo inteiro de link** ao par (**FR-001**, **FR-002**, **FR-009**).

**Independent Test**: obra com F→A, G→B, H→C gera **três** links distintos; titular e editora compartilham o link em cada par.

- [X] T012 [US1] Implementar atribuição determinística de links (pares ordenados lexicograficamente por `chain_id` do titular) em `scripts/migracao/python/assign_links.py` **ou** `scripts/migracao/sql/05_assign_links.sql` conforme `specs/002-chain-link-numeric/research.md`
- [X] T013 [US1] Criar `scripts/migracao/sql/validate_links_three_pairs.sql` validando contagem de links distintos para `atlas_id='AW0MTYO2'` (esperado: pares A/F, B/G, C/H com links 1–3)
- [X] T014 [US1] Criar `scripts/migracao/reports/chain_dangling_export.sql` listando linhas com `chain` não vazio sem `chain_id` correspondente na mesma obra (**CHAIN_DANGLING**)

**Checkpoint**: links numéricos gravados no staging (ou tabela intermédia) por `atlas_id`.

---

## Phase 4: User Story 3 — Titulares sem editor e fallback (Priority: P2)

**Goal**: titulares sem ninguém apontando para seu `chain_id` recebem link exclusivo; editoras com `chain` vazio recebem política de fallback (**FR-004**).

**Independent Test**: `chain_id=D` sem `chain=D` em outra linha não compartilha link com F/G/H; relatório registra fallbacks.

- [X] T015 [US3] Estender `scripts/migracao/python/assign_links.py` (ou `05_assign_links.sql`) para fase 2: links únicos para titulares “soltos” e fase 3: linhas com `chain` vazio, ordem determinística documentada em `specs/002-chain-link-numeric/research.md`
- [X] T016 [US3] Criar `scripts/migracao/reports/fallback_empty_chain.sql` exportando obras/linhas tratadas por fallback para auditoria

**Checkpoint**: todo registro de staging possui `link` inteiro antes de US2/US4.

---

## Phase 5: User Story 2 — Nome do titular na linha editorial (Priority: P1)

**Goal**: cada linha editorial identifica o titular referenciado por `chain` (**FR-005**).

**Independent Test**: para linha F com `chain=A`, o destino permite ver nome do titular da linha A (campo auxiliar, nota ou coluna de exibição acordada).

- [X] T017 [US2] Adicionar coluna ou campo calculado `ref_titular_nome` no staging via `scripts/migracao/sql/06_staging_titular_nome.sql` (JOIN pela obra: `chain` = `chain_id` da linha titular)
- [X] T018 [US2] Propagar `ref_titular_nome` para carga em `scripts/migracao/sql/04_load_integrantes_sbacem_base.sql` (atualizar para preencher nota/campo de UI definido no DDL) ou documentar mapeamento em `scripts/migracao/doc/display_nome_titular.md`

**Checkpoint**: integrantes editoriais carregados com rótulo do titular editado.

---

## Phase 6: User Story 4 — Música 360 por titular controlado (Priority: P1)

**Goal**: cessão MR de `titular`/`titular2`, linhas M360 por link do titular controlado, **`cod_categoria` SE** se houver **E** no link (**FR-006**, **FR-007**, **FR-010** / spec **001**).

**Independent Test**: `AW0MTYO2` com três links BOCA: três M360, MR rateado (default partes iguais), `controlada=true`, `controle_mr=15`, ΣMR=100%.

- [X] T019 [US4] Implementar rateio de cessão por **N** links do mesmo CAE em `scripts/migracao/sql/07_cessao_mr_rateio.sql` (ajuste de arredondamento na última parcela) conforme `specs/002-chain-link-numeric/research.md`
- [X] T020 [US4] Implementar ajuste de **MR** do cedente por linha em `scripts/migracao/sql/08_apply_cessao_cedente.sql` (PR/SR inalterados na fonte)
- [X] T021 [US4] Criar `scripts/migracao/sql/09_insert_m360_integrantes.sql` inserindo participações M360 com `id_pessoa` da env, `link` alinhado ao titular do grupo, `cod_categoria` **SE** ou **E** conforme presença de **E** no link
- [X] T022 [US4] Criar `scripts/migracao/sql/10_update_obra_controlada_controle_mr.sql` setando `controlada` e `controle_mr` = soma MR das linhas M360 (**spec 001**)
- [X] T023 [US4] Criar `scripts/migracao/sql/validate_aw0mtyo2.sql` conferindo links 1–3, três M360 **SE**, somas PR/MR/SR = 100%, `controle_mr=15`

**Checkpoint**: pipeline completo para titulares controlados e obra M360 conforme contrato em `specs/002-chain-link-numeric/contracts/import-pipeline.md`.

---

## Phase 7: Polish e cross-cutting

**Purpose**: validações globais, rollback, alinhamento com constituição e quickstart.

- [X] T024 [P] Criar `scripts/migracao/sql/validate_soma_100_por_obra.sql` detectando obras com ΣPR, ΣMR ou ΣSR ≠ 100 (tolerância documentada)
- [X] T025 [P] Criar `scripts/migracao/rollback/rollback_fase_import.sql` com blocos `DELETE` comentados por fase (integrantes M360, integrantes base, obras, pessoas importadas) alinhado a `.specify/memory/constitution.md` princípio IV
- [X] T026 Atualizar `scripts/remover_obras_sbacem.sql` ou referenciar rollback novo no `scripts/migracao/README.md` para não haver dois fluxos conflitantes
- [X] T027 Criar `scripts/migracao/sql/validate_cardinalidade_fonte_destino.sql` comparando contagem de `atlas_id` distintos em `mdb.sbacem` vs `obras.obra` tenant 38
- [ ] T028 Executar checklist de `specs/002-chain-link-numeric/quickstart.md` em ambiente de dev e registrar resultados (evidências) em `specs/002-chain-link-numeric/reports/` ou anexo datado no README da migração *(template: `specs/002-chain-link-numeric/reports/EVIDENCIAS_quickstart_TEMPLATE.md`)*

---

## Dependencies & Execution Order

### Phase dependencies

- **Phase 1** → sem dependências.
- **Phase 2** → depende de Phase 1; **bloqueia** US1–US4.
- **Phase 3 (US1)** → depende de Phase 2.
- **Phase 4 (US3)** → depende de Phase 3 (estende o mesmo módulo SQL/Python de links).
- **Phase 5 (US2)** → depende de Phase 4 (links finais no staging).
- **Phase 6 (US4)** → depende de Phase 5 e integrantes base **T011**; ajusta MR e insere M360.
- **Phase 7** → depende de Phase 6.

### User story dependencies (resumo)

| Story | Depende de |
|-------|------------|
| US1 | Foundational |
| US3 | US1 (mesmo algoritmo) |
| US2 | US3 |
| US4 | US2 + integrantes base (T011) |

### Oportunidades em paralelo

- **T002**, **T003**, **T007** (Phase 1–2) em paralelo.
- **T024**, **T025** (Polish) em paralelo após Phase 6.

### Exemplo paralelo (Phase 2)

```text
T007 scripts/migracao/doc/role_map_sbacem_to_categoria.md
T002 scripts/migracao/.env.example
T003 scripts/migracao/reports/.gitkeep
```

---

## Parallel Example: User Story 4

```text
T019 scripts/migracao/sql/07_cessao_mr_rateio.sql
T020 scripts/migracao/sql/08_apply_cessao_cedente.sql
```
*(sequência recomendada: T019 → T020 → T021 → T022 → T023; T019/T020 só paralelizam se arquivos forem independentes — aqui T020 depende da saída conceitual de T019)*

---

## Implementation Strategy

### MVP (mínimo)

1. Phase 1 + Phase 2  
2. Phase 3 (US1) + Phase 4 (US3) — links completos  
3. Validar `AW0MTYO2` apenas com queries de link (sem M360)

### Entrega incremental

1. Adicionar Phase 5 (US2) — nomes em integrantes editoriais.  
2. Adicionar Phase 6 (US4) — cessão + M360 + `controlada` / `controle_mr`.  
3. Phase 7 — validações e rollback.

### Sugestão de escopo MVP para demo

- **US1 + US3 + T013** (validação F/G/H) em **dev**, sem escrita em produção.

---

## Métricas desta lista

| Métrica | Valor |
|---------|-------|
| **Total de tarefas** | 28 (27 concluídas na implementação; **T028** manual em dev) |
| **US1** | 3 |
| **US2** | 2 |
| **US3** | 2 |
| **US4** | 5 |
| **Setup + Foundational + Polish** | 16 |
| **Tarefas com [P]** | 6 |

**Critérios de teste independente por story**: reproduzidos nos cabeçalhos das Phases 3–6.

**Validação de formato**: todas as linhas de tarefa usam `- [X] Tnnn ...` com **caminho de arquivo** explícito; rótulos **[USn]** apenas nas Phases 3–6.

---

## Notes

- Spec **001** (`specs/001-import-obras-mdb-titular/spec.md`) rege percentuais, `controlada`, `titular2` e **FR-010** originais — manter leitura lado a lado na implementação.
- Nenhum INSERT fora de `id_tenant=38` / `id_configuracao=61`.
