# Executa os .sql principais na ordem (só precisa do psql no PATH).
# Uso:
#   cd scripts\migracao
#   $env:PGPASSWORD = "senha"
#   .\executar_sequencia.ps1 -DbHost db.exemplo.com -User backstage -Database woodstock
#
# Só listar arquivos (não executa):
#   .\executar_sequencia.ps1 -ListarApenas

param(
    [Alias("Host")]
    [string] $DbHost = "localhost",
    [int] $Port = 5432,
    [string] $User = "backstage",
    [string] $Database = "woodstock",
    [switch] $ListarApenas,
    [switch] $IncluirOpcionaisCarga,
    [switch] $IncluirValidacoes
)

$ErrorActionPreference = "Stop"
$Base = $PSScriptRoot

$Principal = @(
    "staging\01_staging_tables.sql",
    "sql\populate_staging_from_sbacem.sql",
    "ddl\verify_obra_integrante_link.sql",
    "sql\titular_cessao_unificada.sql",
    "sql\05_assign_links.sql",
    "sql\06_staging_titular_nome.sql",
    "sql\07_cessao_mr_rateio.sql",
    "sql\08_apply_cessao_cedente.sql"
)

$OpcionaisCarga = @(
    "sql\02_load_pessoas_dedup.sql",
    "sql\03_load_obras.sql",
    "sql\04_load_integrantes_sbacem_base.sql",
    "sql\09_insert_m360_integrantes.sql",
    "sql\10_update_obra_controlada_controle_mr.sql"
)

$Validacoes = @(
    "sql\validate_links_three_pairs.sql",
    "sql\validate_aw0mtyo2.sql",
    "reports\chain_dangling_export.sql",
    "reports\fallback_empty_chain.sql",
    "sql\validate_cardinalidade_fonte_destino.sql"
)

$Lista = @() + $Principal
if ($IncluirOpcionaisCarga) { $Lista += $OpcionaisCarga }
if ($IncluirValidacoes) { $Lista += $Validacoes }

$n = 0
foreach ($rel in $Lista) {
    $n++
    $full = Join-Path $Base $rel
    if (-not (Test-Path -LiteralPath $full)) {
        Write-Error "Arquivo nao encontrado: $full"
    }
    Write-Host ("[{0,2}/{1}] {2}" -f $n, $Lista.Count, $rel)
    if ($ListarApenas) { continue }

    $args = @(
        "-h$DbHost",
        "-p$Port",
        "-U$User",
        "-d$Database",
        "-v", "ON_ERROR_STOP=1",
        "-f", $full
    )
    & psql @args
    if ($LASTEXITCODE -ne 0) {
        Write-Error "psql falhou no passo: $rel (codigo $LASTEXITCODE)"
    }
}

if ($ListarApenas) {
    Write-Host "`nTotal: $($Lista.Count) arquivos (use sem -ListarApenas para executar)."
} else {
    Write-Host "`nConcluido: $($Lista.Count) script(s)."
}
