# Data model — Arquivo único (staging)

## Objetos criados ou alterados pelo `migracao_staging_um_arquivo.sql`

| Objeto | Tipo | Ação |
|--------|------|------|
| `migracao_stg` | schema | `CREATE IF NOT EXISTS` |
| `migracao_stg.sbacem_import_staging` | table | `DROP` + `CREATE` |
| `migracao_stg.vw_cessao_mr_por_cae` | view | `CREATE OR REPLACE` |
| `migracao_stg.vw_parcela_cessao_por_link` | view | `CREATE OR REPLACE` |
| Linhas em `sbacem_import_staging` | data | `TRUNCATE` + `INSERT` + `UPDATE` |

## Colunas principais (staging)

| Coluna | Uso |
|--------|-----|
| `atlas_id` | chave obra |
| `chain_id`, `chain` | víncio MDB |
| `pr_pct`, `mr_pct`, `sr_pct` | percentuais normalizados |
| `numero_link` | inteiro editorial |
| `ref_titular_nome` | exibição FR-005 |

## Leitura (não mutação de negócio)

- `mdb.sbacem`, `mdb.titular`, `mdb.titular2`
- `information_schema.columns` (checagem `numero_link`)

## Fora do escopo deste arquivo

- `obras.obra`, `pessoas.pessoa`, `obras.obra_integrante` (INSERT)
