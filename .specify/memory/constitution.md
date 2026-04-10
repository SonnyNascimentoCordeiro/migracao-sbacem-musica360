<!-- 
SYNC IMPACT REPORT
====================
Version: 0.1.0 (initial ratification)
Created: 2026-04-04
Principles: 5 core principles defined
Sections: Technical constraints + Development workflow + Governance
Templates updated: plan-template, spec-template, tasks-template (no changes needed - generic)
Status: COMPLETE - All placeholders filled
-->

# SBACEM → Woodstock Migration Constitution

## Core Principles

### I. Data Integrity First
Every record imported from SBACEM must be traceable to its source. No data loss, no silent transformations. All person identifications (IPI numbers) and work identifications (atlas IDs) must maintain backward references via `obra_de_para` and `pessoa_de_para` tables for audit and reconciliation.

### II. Tenant Isolation (NON-NEGOTIABLE)
All imported data MUST target exclusively `id_tenant=38` and `id_configuracao=61`. Zero tolerance for data entering other tenants. Every INSERT statement must include explicit `WHERE id_tenant = 38` safeguards. Code review gates require tenant verification before merge.

### III. Type Safety in Data Transformation
Percentages must convert `","` → `"."` before cast to float. Dates must be ISO 8601. Roles must map to valid `cod_categoria` values. No type coercion surprises—catch mismatches during load, not in production queries.

### IV. Rollback Capability
Every migration phase must be independently reversible. SQL scripts must include corresponding DELETE statements (commented, for manual use). If a phase fails, subsequent phases must wait for explicit restart, not auto-resume. No cascading failures.

### V. Verification Before Commit
No import stage completes without row-count audit and sample spot-checks. Query results must be validated against expected cardinality BEFORE data modification. Tests must cover boundary cases (empty fields, duplicate IPs, missing roles).

## Technical Constraints

- **Database**: PostgreSQL 13+ | Woodstock production (`mcp__postgres-woodstock-prod__query` via MCP)
- **Tenant Scope**: Rigidly enforced—id_tenant=38, id_configuracao=61 only
- **Source Data**: Read-only access to `mdb.sbacem` (source system)
- **Decimal Handling**: All percentages must use `REPLACE(field, ',', '.')::float` to handle source CSV format
- **Date Format**: All timestamps ISO 8601 (e.g., `2026-04-04T00:00:00Z`)
- **Deduplication Keys**: `ipi_name_number` for people, `atlas_id` for works—must not create duplicates
- **Character Encoding**: UTF-8 throughout; uppercase normalization for person names
- **Performance Gate**: Import must complete <10 minutes for 125k+ works; optimize queries accordingly
- **Audit Trail**: Every imported record must have `importado=true` and `criacao=now()` timestamp

## Development Workflow

1. **Planning Phase**: Every feature/script must include data flow diagram, record counts, and mapping table (source field → target field → transformation logic)

2. **Implementation Phase**:
   - Write SQL scripts with explicit tenant filters
   - Include commented-out DELETE scripts for rollback
   - Add row-count validation queries before/after each phase
   - Test with small subsets first (sample 100 rows)

3. **Verification Phase** (MANDATORY):
   - Run spot-checks: SELECT 10 random imported records and verify field mapping
   - Compare cardinality: source count vs. target count (must match exactly or document why)
   - Validate referential integrity: all FK relationships must be satisfied
   - Log all queries and results for audit trail

4. **Code Review Process**:
   - PR must include: SQL script + verification queries + spot-check results
   - Reviewer must validate tenant isolation, type conversions, and rollback capability
   - Final approval only when "VERIFIED" tag present in commit message

5. **Merge & Deployment**:
   - Feature branch → main only after all gates pass
   - SQL execution happens via psql/DBeaver (out-of-band, not CI/CD)
   - Merge commit includes result summary (e.g., "Imported 125,522 works, 32,915 people")

## Governance

### Amendment Procedure
Changes to this constitution require:
1. Document rationale in PR description (why the change, impact)
2. Get approval from both product owner and tech lead
3. Update version per semantic versioning rules
4. Propagate changes to dependent templates
5. Tag commit with `docs: amend constitution to vX.Y.Z`

### Versioning Policy
- **MAJOR**: Principle removal or redefinition (e.g., changing tenant from 38 to 40)
- **MINOR**: New principle added or section expanded (e.g., adding compliance gate)
- **PATCH**: Clarifications, wording, typo fixes (e.g., better explanation of IPI mapping)

### Compliance Review
- Every feature PR must reference which constitution principles it satisfies
- Code review must explicitly verify tenant isolation, type safety, and data integrity gates
- Failed gates block merge; exceptions require documented waiver with stakeholder sign-off
- Use `CLAUDE.md` in this repo for runtime development guidance and agent workflows

**Version**: 0.1.0 | **Ratified**: 2026-04-04 | **Last Amended**: 2026-04-04
