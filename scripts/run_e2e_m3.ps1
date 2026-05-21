<#
.SYNOPSIS
    Ejecuta la suite E2E de reportes M3 (concentracion_anual) en Docker.

.DESCRIPTION
    Pipeline autocontenido. Ejecuta M3 pytest dentro de un contenedor Docker.
    No levanta MK, MV ni Qdrant — M3 lee directamente desde DuckDB.

    Prerequisito: datos/minera.duckdb presente (ejecutar dbt seed && dbt run primero).

.PARAMETER Suite
    Ruta relativa al YAML de la suite. Por defecto: tests/e2e_m3_reportes.yaml

.PARAMETER Imagen
    Imagen Docker con Illari. Por defecto: ghcr.io/asistente-agentico/illari:dev-0.7.1

.PARAMETER Dev
    Si se especifica:
      - Monta tests/ local de Illari en /app/tests (usa conftest de disco, no de imagen).
      - Activa flags pytest -v -s (verbose + stdout sin captura).

.EXAMPLE
    .\scripts\run_e2e_m3.ps1 -Dev
    .\scripts\run_e2e_m3.ps1 -Imagen ghcr.io/asistente-agentico/illari:dev-0.7.2
#>

param(
    [string]$Suite  = "tests/e2e_m3_reportes.yaml",
    [string]$Imagen = "ghcr.io/asistente-agentico/illari:dev-0.7.1",
    [switch]$Dev
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding          = [System.Text.Encoding]::UTF8

# -- Rutas ------------------------------------------------------------------
$repoRaiz = Split-Path -Parent $PSScriptRoot
$suiteAbs = Join-Path $repoRaiz $Suite

# -- Validaciones previas ---------------------------------------------------
if (-not (Test-Path $suiteAbs)) {
    Write-Error "Suite no encontrada: $suiteAbs"
    exit 1
}

$duckdb = Join-Path $repoRaiz "datos\minera.duckdb"
if (-not (Test-Path $duckdb)) {
    Write-Error "datos/minera.duckdb no encontrado. Ejecuta 'dbt seed' y 'dbt run' primero."
    exit 1
}

# -- Nombre del archivo de resultado ----------------------------------------
$suiteName = [IO.Path]::GetFileNameWithoutExtension($suiteAbs)
$versionLine = Get-Content $suiteAbs | Select-String "^\s*version\s*:"
if ($versionLine) {
    $version = ($versionLine.ToString() -replace '^\s*version\s*:\s*["'']?', '') -replace '["'']?\s*$', ''
} else {
    $version = "sin-version"
}
$ts        = Get-Date -Format "yyyyMMdd-HHmmss"
$devSuffix = if ($Dev) { "-dev" } else { "" }
$outDir    = Join-Path $repoRaiz "tests\results"
$outFile   = Join-Path $outDir "$suiteName-v$version$devSuffix-$ts.txt"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# -- Modo dev: montar tests/ local de Illari --------------------------------
$devMount = @()
if ($Dev) {
    $illariTests = Join-Path (Split-Path -Parent $repoRaiz) "Illari\tests"
    if (Test-Path $illariTests) {
        $devMount = @("-v", "${illariTests}:/app/tests")
        Write-Host "Tests   : $illariTests (montado en /app/tests)"
    } else {
        Write-Host "Tests   : usando tests embebidos en la imagen ($illariTests no encontrado)"
    }
}

# -- Info -------------------------------------------------------------------
$modo = if ($Dev) { "dev (verbose)" } else { "normal" }
Write-Host ""
Write-Host "=== Illari E2E M3 (reportes) — minera ==="
Write-Host "Suite  : $suiteName v$version"
Write-Host "Modo   : $modo"
Write-Host "Imagen : $Imagen"
Write-Host "Output : $outFile"
Write-Host ""

# -- Descargar imagen -------------------------------------------------------
Write-Host "[1/2] docker pull $Imagen..."
docker pull $Imagen
Write-Host ""

# -- Ejecutar suite E2E M3 --------------------------------------------------
Write-Host "[2/2] Ejecutando suite E2E M3..."
Write-Host ""

$pytestFlags = if ($Dev) { "-v -s -m e2e" } else { "-v -m e2e" }
$verboseVal  = if ($Dev) { "1" } else { "0" }

$suiteEnContainer = "/cliente/minera/$($Suite -replace '\\','/')"

$dockerArgs = @(
    "run", "--rm",
    "-v", "${repoRaiz}:/cliente/minera"
)
if ($devMount.Count -gt 0) {
    $dockerArgs += $devMount
}
$dockerArgs += @(
    "-e", "ILLARI_E2E_M3=$suiteEnContainer",
    "-e", "ILLARI_E2E_CLIENTE=/cliente/minera",
    "-e", "ILLARI_E2E_VERBOSE=$verboseVal",
    "--entrypoint", "sh",
    $Imagen,
    "-c", "python -m pytest /app/tests/e2e_m3/ $pytestFlags"
)

New-Item -ItemType File -Force -Path $outFile | Out-Null
& docker @dockerArgs | ForEach-Object { $_; $_ | Out-File -FilePath $outFile -Encoding UTF8 -Append }

$exitCode = $LASTEXITCODE

Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "PASSED -- resultado guardado en: $outFile" -ForegroundColor Green
} else {
    Write-Host "FAILED (exit $exitCode) -- resultado guardado en: $outFile" -ForegroundColor Red
}

exit $exitCode
