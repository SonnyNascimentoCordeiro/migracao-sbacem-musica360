# Comandos `psql` na ordem (copiar e colar)

Ajuste **HOST**, **PORTA**, **USUÁRIO** e **SENHA**. No PowerShell, na pasta `scripts/migracao`:

```powershell
$env:PGPASSWORD = "SUA_SENHA"
$h="HOST"; $p="5432"; $U="backstage"; $d="woodstock"
```

Depois rode **um bloco por vez** (ou use `executar_sequencia.ps1`).

```powershell
psql -h $h -p $p -U $U -d $d -v ON_ERROR_STOP=1 -f staging/01_staging_tables.sql
psql -h $h -p $p -U $U -d $d -v ON_ERROR_STOP=1 -f sql/populate_staging_from_sbacem.sql
psql -h $h -p $p -U $U -d $d -v ON_ERROR_STOP=1 -f ddl/verify_obra_integrante_link.sql
psql -h $h -p $p -U $U -d $d -v ON_ERROR_STOP=1 -f sql/titular_cessao_unificada.sql
psql -h $h -p $p -U $U -d $d -v ON_ERROR_STOP=1 -f sql/05_assign_links.sql
psql -h $h -p $p -U $U -d $d -v ON_ERROR_STOP=1 -f sql/06_staging_titular_nome.sql
psql -h $h -p $p -U $U -d $d -v ON_ERROR_STOP=1 -f sql/07_cessao_mr_rateio.sql
psql -h $h -p $p -U $U -d $d -v ON_ERROR_STOP=1 -f sql/08_apply_cessao_cedente.sql
```

**Opcional** (só depois de alinhar DDL / descomentar inserts):

```powershell
psql -h $h -p $p -U $U -d $d -v ON_ERROR_STOP=1 -f sql/02_load_pessoas_dedup.sql
psql -h $h -p $p -U $U -d $d -v ON_ERROR_STOP=1 -f sql/03_load_obras.sql
psql -h $h -p $p -U $U -d $d -v ON_ERROR_STOP=1 -f sql/04_load_integrantes_sbacem_base.sql
psql -h $h -p $p -U $U -d $d -v ON_ERROR_STOP=1 -f sql/09_insert_m360_integrantes.sql
psql -h $h -p $p -U $U -d $d -v ON_ERROR_STOP=1 -f sql/10_update_obra_controlada_controle_mr.sql
```
