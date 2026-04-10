# Specification Quality Checklist: Importação de obras MDB com titulares (060) e Música 360

**Purpose**: Validate specification completeness and quality before proceeding to planning  
**Created**: 2026-04-04  
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Validation Review (2026-04-04)

| Item | Result | Notes |
|------|--------|--------|
| Nomenclatura MDB / tabelas | Pass | Nomes `mdb.sbacem`, `titular`, `titular2` constam a pedido do solicitante para alinhar negócio e dados legados; critérios de sucesso permanecem agnósticos de stack. |
| FR-006 “relatório ou consultas” | Pass | Forma de evidência deixada como opção de negócio, sem impor ferramenta. |

## Notes

- Regras numéricas exatas de cessão para sociedade 060 ficam documentadas na fase de plano/implementação ou em anexo de negócio; a spec assume confirmação com o material já existente no projeto.
- Pronto para `/speckit.plan` ou `/speckit.clarify` se o negócio quiser ajustar política de obras sem titular ou tolerância de arredondamento.
- **2026-04-04 (clarify):** obra exemplar `AW0MTYO2` e rascunhos DR-EX-* adicionados à spec.
- **2026-04-04 (clarify, follow-up):** regra **cessão = `titular.percentual`**, **titular destino = quota sbacem − cessão**, **M360 = cessão**; conflito **cessão > quota** documentado (ex. `AW0MTYO2` / 00802972439).
- **2026-04-04 (clarify):** adicionada **projeção numérica** `AW0MTYO2` (obra + integrantes) na spec, com premissa de **agregação F+G+H**.
- **2026-04-04 (clarify):** **M360 só MR**, **cessão só MR**, **`controlada` + `controle_mr`**, **`chain_id`/`chain` = link**; formato alvo atualizado na spec.  
- **2026-04-04:** **FR-010** — **`cod_categoria` M360 = `SE`** com **E** no mesmo link (ou cedente **E** no modelo agregado); senão **`E`**.
