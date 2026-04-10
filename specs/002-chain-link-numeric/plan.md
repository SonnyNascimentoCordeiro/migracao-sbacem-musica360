# Implementation Plan: Links numéricos, cessão MR e Música 360

**Branch**: `002-chain-link-numeric` | **Date**: 2026-04-04 | **Spec**: [spec.md](./spec.md)

**Staging em um único arquivo**: a sequência de preparação em `migracao_stg` está consolidada em `scripts/migracao/migracao_staging_um_arquivo.sql` — ver spec **`003-consolidated-migration-sql`** e [plan.md](../003-consolidated-migration-sql/plan.md).

## Summary

Converter a semântica MDB (`chain` → `chain_id`) em **`numero_link` inteiro** no staging; aplicar cessão MR a partir de `mdb.titular` / `mdb.titular2` com rateio quando o mesmo CAE aparece em vários links; inserir Música 360 no **mesmo link** do titular controlado, com **`SE` vs `E`** conforme **FR-010** da spec **001**. Carga final em `obras` / `pessoas` permanece em scripts dedicados (DDL `numero_link` no destino quando aprovado).

## Technical Context

**Language/Version**: SQL (PostgreSQL 13+), Python 3 opcional (`run_pipeline.py`)  
**Primary Dependencies**: `psql` ou DBeaver; opcional `psycopg2`, `sqlparse`, `python-dotenv`  
**Storage**: `mdb.*`, schema `migracao_stg`  
**Testing**: contagens no staging; obra amostra `AW0MTYO2`  
**Target Platform**: PostgreSQL (Woodstock)  
**Project Type**: pipeline de migração (SQL + relatórios)  
**Performance Goals**: processar ~302k linhas fonte sem timeout de sessão única inadequado  
**Constraints**: sem `DELETE` em cadastro Woodstock; cessão só em **MR**; titular+titular2 sem duplicar cessão (**FR-008**)  
**Scale/Scope**: 125k obras distintas; 32k IPs distintos (fonte)

## Constitution Check

Alinhado a **Data Integrity**, **Tenant Isolation** (INSERTs finais só tenant 38), **Type Safety** (vírgula → ponto), **Rollback** (staging recriável), **Verification** (queries pós-pipeline). Ver [research.md](./research.md).

## Project Structure

```text
specs/002-chain-link-numeric/   — spec, plan, research, data-model, tasks, contracts
scripts/migracao/               — SQL modulares + migracao_staging_um_arquivo.sql
```

## Phase 0 — Research

Concluído: [research.md](./research.md).

## Phase 1 — Design

- [data-model.md](./data-model.md)  
- [contracts/import-pipeline.md](./contracts/import-pipeline.md)  
- [quickstart.md](./quickstart.md)

## Phase 2 — Implementation (tarefas)

Ver [tasks.md](./tasks.md) (T001–T027; T028 carga destino manual quando DDL aprovado).

---

**Nota**: Se `setup-plan.ps1` sobrescrever este arquivo com template vazio, restaurar a partir do repositório ou copiar o resumo acima.
