# Implementation Plan: Um único arquivo SQL (staging)

**Branch**: `003-consolidated-migration-sql` | **Date**: 2026-04-04 | **Spec**: [spec.md](./spec.md)  
**Input**: “eu quero apenas um arquivo A” — operador executa **um** `.sql` para todo o bloco de staging (sem pipeline fragmentado).

**Artefato canônico**: `scripts/migracao/migracao_staging_um_arquivo.sql`

## Summary

Consolidar a sequência de preparação de dados (**schema `migracao_stg`**, carga a partir de `mdb.sbacem`, verificação de DDL de link, views de cessão, atribuição de `numero_link`, `ref_titular_nome`, parcela e ajuste de MR no staging) em **um único arquivo** executável via `psql -f` ou DBeaver. Manter scripts modulares como referência de desenvolvimento; definir processo para **evitar deriva** entre modular e único.

## Technical Context

**Language/Version**: SQL (PostgreSQL 13+)  
**Primary Dependencies**: Nenhuma (cliente `psql` ou DBeaver)  
**Storage**: mesmo banco Woodstock com `mdb.*` e `migracao_stg`  
**Testing**: consultas pós-execução em `migracao_stg.sbacem_import_staging`; obra amostra `AW0MTYO2`  
**Target Platform**: servidor PostgreSQL  
**Project Type**: script de migração (artefato único)  
**Performance Goals**: mesma ordem de grandeza do pipeline modular (~302k linhas fonte → staging)  
**Constraints**: sem `DELETE` em `obras`/`pessoas`; só `DROP`/`TRUNCATE` em tabela de staging  
**Scale/Scope**: escopo **até staging**; carga final Woodstock fora deste arquivo

## Constitution Check

| Princípio | Atendimento |
|-----------|-------------|
| **I. Data Integrity** | Fonte `mdb.sbacem` intacta; staging recriável; rastreio por `atlas_id` / linhas |
| **II. Tenant Isolation** | Este arquivo **não** grava em outros tenants; INSERTs finais continuam em scripts futuros com `id_tenant=38` |
| **III. Type Safety** | `REPLACE(..., ',', '.')` mantido no bloco de INSERT |
| **IV. Rollback** | Reexecução do arquivo ou `DROP` staging; sem CASCADE em negócio |
| **V. Verification** | Incluir no quickstart contagens e amostra pós-`SELECT` |

**Gate**: aprovado para staging; carga em `obras` exige plano separado (spec **001**/**002**).

## Project Structure

```text
scripts/migracao/
├── migracao_staging_um_arquivo.sql   # CANÔNICO — executar este
├── sql/ … staging/ …                # modulares (paridade com o único)
└── README.md
```

## Complexity Tracking

Nenhuma violação; duplicação modular ↔ único é **trade-off** documentado em `research.md`.

## Phase 0 — Research

Saída: [research.md](./research.md) (fonte da verdade, geração, paridade).

## Phase 1 — Design

- [data-model.md](./data-model.md) — objetos tocados pelo arquivo único.  
- [contracts/single-file-staging.md](./contracts/single-file-staging.md) — invariantes.  
- [quickstart.md](./quickstart.md) — execução e verificação.

## Phase 2 — Manutenção (contínua)

1. Qualquer mudança de regra nos modulares **deve** refletir no arquivo único (ou script de concatenação no CI).  
2. Revisão trimestral: diff lógico entre ordem modular e único.  
3. Quando existir carga Woodstock estável, **opcional**: segundo arquivo único `migracao_destino_um_arquivo.sql` (fora do escopo atual da spec **003**).

---

**Artefatos**: `plan.md` (este), `research.md`, `data-model.md`, `contracts/single-file-staging.md`, `quickstart.md`.
