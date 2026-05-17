<#
.SYNOPSIS
    Ejecuta la suite E2E del cliente minera y guarda el resultado en un archivo.

.DESCRIPTION
    Lee el YAML de la suite indicada, extrae nombre y version, construye el
    nombre del archivo de resultado y lanza pytest dentro de la imagen Docker
    del producto. El resultado queda en tests/results/ del repo minera.

.PARAMETER Suite
    Ruta al archivo YAML de la suite. Por defecto: tests/e2e.yaml

.PARAMETER MasterSecret
    MASTER_SECRET usado al indexar los chunks. Si no se pasa, se lee de la
    variable de entorno MASTER_SECRET.

.PARAMETER Imagen
    Imagen Docker del producto. Por defecto: ghcr.io/asistente-agentico/illari:dev-0.6.2

.EXAMPLE
    .\scripts\run_e2e.ps1
    .\scripts\run_e2e.ps1 -Suite tests/e2e.yaml -MasterSecret "abc123..."
#>

param(
    [string]$Suite        = "tests/e2e.yaml",
    [string]$MasterSecret = $env:MASTER_SECRET,
    [string]$Imagen       = "ghcr.io/asistente-agentico/illari:dev-0.6.2"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Rutas ──────────────────────────────────────────────────────────────────
$repoRaiz  = Split-Path -Parent $PSScriptRoot
$suiteAbs  = Join-Path $repoRaiz $Suite

if (-not (Test-Path $suiteAbs)) {
    Write-Error "Suite no encontrada: $suiteAbs"
    exit 1
}

if (-not $MasterSecret) {
    Write-Error "MASTER_SECRET no definido. Pasalo con -MasterSecret o como variable de entorno."
    exit 1
}

# ── Leer nombre y version del YAML ────────────────────────────────────────
$suiteName = [IO.Path]::GetFileNameWithoutExtension($suiteAbs)

$versionLine = Get-Content $suiteAbs | Select-String "^\s*version\s*:"
if ($versionLine) {
    $version = ($versionLine.ToString() -replace '^\s*version\s*:\s*["'']?', '') -replace '["'']?\s*$', ''
} else {
    $version = "sin-version"
}

# ── Nombre del archivo de resultado ───────────────────────────────────────
$ts      = Get-Date -Format "yyyyMMdd-HHmmss"
$outName = "$suiteName-v$version-$ts.txt"
$outDir  = Join-Path $repoRaiz "tests\results"
$outFile = Join-Path $outDir $outName

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# ── Rutas dentro del contenedor ───────────────────────────────────────────
$raizContenedor   = "/cliente/minera"
$suiteContenedor  = "$raizContenedor/$(($Suite -replace '\\','/'))"
$dominioContenedor = "$raizContenedor/configuracion/dominio.yaml"

# ── Ejecutar ──────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Suite  : $suiteName v$version"
Write-Host "Imagen : $Imagen"
Write-Host "Output : $outFile"
Write-Host ""

docker run --rm `
    -v "${repoRaiz}:/cliente/minera" `
    -e "ILLARI_E2E_SUITE=$suiteContenedor" `
    -e "ILLARI_E2E_DOMINIO=$dominioContenedor" `
    -e "MASTER_SECRET=$MasterSecret" `
    -w $raizContenedor `
    --entrypoint sh `
    $Imagen `
    -c "pip install fastembed -q 2>/dev/null && python -m pytest /app/tests/e2e/ -v -m e2e" `
    | Tee-Object -FilePath $outFile

$exitCode = $LASTEXITCODE

Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "PASSED - resultado guardado en: $outFile" -ForegroundColor Green
} else {
    Write-Host "FAILED (exit $exitCode) - resultado guardado en: $outFile" -ForegroundColor Red
}

exit $exitCode
