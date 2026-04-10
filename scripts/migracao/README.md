# Migração MDB → Woodstock (tenant 38 / config 61)

**Aviso:** todo `INSERT`/`UPDATE` no destino deve usar **`id_tenant = 38`** e obras com **`id_configuracao = 61`**. Não executar em produção sem revisão e backup.

## Um arquivo só (recomendado)

Execute **tudo do staging** de uma vez:

- **`migracao_staging_um_arquivo.sql`** — contém a mesma sequência dos passos 1–8 (staging → links → titular nome → cessão MR).  
  `psql ... -f migracao_staging_um_arquivo.sql` ou DBeaver (executar script completo).

## Modo simples (só a ordem dos SQL)

1. Lista numerada: **`SEQUENCIA_EXECUCAO.txt`**
2. Comandos `psql` prontos para copiar: **`SEQUENCIA_SQL_CMD.md`**
3. PowerShell (precisa do `psql` no PATH):

```powershell
cd scripts\migracao
$env:PGPASSWORD = "senha"
.\executar_sequencia.ps1 -DbHost SEU_HOST -User backstage -Database woodstock
.\executar_sequencia.ps1 -ListarApenas
.\executar_sequencia.ps1 -IncluirValidacoes
```

## Executar tudo de uma vez (Python)

Na pasta `scripts/migracao`:

```powershell
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
# Edite .env: DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD

python run_pipeline.py              # staging + links + cessão MR (passos 1–8 do fluxo abaixo)
python run_pipeline.py --validate   # + validações (AW0MTYO2, cardinalidade, etc.)
python run_pipeline.py --load-destino # + esqueletos 02/03/04 (SELECT TODO)
python run_pipeline.py --dry-run    # só lista os .sql que seriam executados
python run_pipeline.py --use-psql   # usa o cliente psql em vez de psycopg2
```

O script usa **psycopg2** + **sqlparse** para enviar cada comando ao PostgreSQL (não exige `psql` no PATH, salvo `--use-psql`).

## Ordem sugerida (alinhada a `specs/002-chain-link-numeric/tasks.md`)

1. `staging/01_staging_tables.sql` — cria schema e tabela staging.
2. `sql/populate_staging_from_sbacem.sql` — copia `mdb.sbacem` → staging.
3. `ddl/verify_obra_integrante_link.sql` — confere coluna de **link** no destino (`numero_link` ou equivalente).
4. `sql/titular_cessao_unificada.sql` — view `mdb.titular` + `mdb.titular2`.
5. `sql/05_assign_links.sql` — fases 1–3: pares editoriais, titulares soltos, fallback `chain` vazio.
6. `sql/06_staging_titular_nome.sql` — preenche `ref_titular_nome`.
7. `sql/02_load_pessoas_dedup.sql` → `03_load_obras.sql` → `04_load_integrantes_sbacem_base.sql` — ajustar nomes de colunas ao DDL real antes de rodar.
8. `sql/07_cessao_mr_rateio.sql` + `08_apply_cessao_cedente.sql` — cessão MR.
9. `sql/09_insert_m360_integrantes.sql` + `10_update_obra_controlada_controle_mr.sql`.
10. Validações em `sql/validate_*.sql` e relatórios em `reports/`.

## Rollback

- Ver `rollback/rollback_fase_import.sql` (comandos comentados).
- Script legado: `scripts/remover_obras_sbacem.sql` — mantido para remoções pontuais; preferir o rollback por fases quando a carga completa estiver versionada.

## Python opcional

- `python/assign_links.py` — lembrete para executar `05_assign_links.sql` via `psql` se não usar cliente SQL interativo.

## Configuração

Copiar `.env.example` para `.env` (não commitar) e preencher credenciais / IDs.
