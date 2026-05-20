<#
.SYNOPSIS
    E2E completo de lectura: MK + MV + M1 embed + M2 tests en un contenedor Docker.

.DESCRIPTION
    Pipeline totalmente autocontenido. Todo ocurre dentro de un único contenedor:

    [Pre] Limpia qdrant_data/ local para arranque limpio.

    Dentro del contenedor:
      [A]   Copia el repo a /tmp/minera (tmpfs nativo Linux).
            Motivo: Qdrant embedded usa portalocker/flock, que falla sobre bind-mounts
            NTFS/9P de WSL2. El tmpfs evita el "Resource temporarily unavailable".
      [A.1] Pre-crea la colección Qdrant "chunks" (size=384, COSINE).
            Motivo: QdrantAdapter y el lifespan de MV nunca llaman create_collection;
            el upsert falla silenciosamente si la colección no existe.
      [A.2] Pre-descarga el modelo de embeddings (paraphrase-multilingual-MiniLM-L12-v2).
            Motivo: la imagen no bake el modelo; la primera descarga tarda 27-60 s.
            Si MV arranca sin el modelo en caché, el health-check agota los reintentos
            antes de que MV esté listo.
      [B]   Arranca MK en :8003 con MASTER_SECRET.
      [C]   Arranca MV en :8002 (CLIENTE_DIR=/tmp/minera, MK_URL, MA_JWKS_URL).
      [D]   Espera a que MV responda /health (10 reintentos × 3 s).
      [E]   Corre M1 embed:
              --raiz /tmp/minera  →  raiz.name="minera"  →  minera.duckdb encontrado
              MV_URL=http://localhost:8002  →  sube chunks via HTTP al MV real
      [F]   Detiene MV y MK: SIGTERM → sleep 2 → SIGKILL → sleep 1.
            El doble kill garantiza que el lock de Qdrant quede libre antes de pytest.
      [G]   Corre pytest M2 (conftest usa TestClient de MV con el mismo qdrant_data).

    Prerequisito: datos/minera.duckdb presente (ejecutar dbt seed && dbt run primero).

.PARAMETER Suite
    Ruta relativa al YAML de la suite. Por defecto: tests/e2e_lectura.yaml

.PARAMETER MasterSecret
    MASTER_SECRET para cifrado de chunks y validación de JWT.
    Si no se pasa, se lee de la variable de entorno MASTER_SECRET o del archivo .env.

.PARAMETER Imagen
    Imagen Docker con Illari. Por defecto: ghcr.io/asistente-agentico/illari:dev-0.7.1

.PARAMETER Dev
    Si se especifica:
      - Monta tests/ local de Illari en /app/tests (usa conftest de disco, no de imagen).
      - Activa flags pytest -v -s (verbose + stdout sin captura).

.EXAMPLE
    .\scripts\run_e2e_lectura.ps1 -Dev
    .\scripts\run_e2e_lectura.ps1 -MasterSecret "abc..." -Dev
    .\scripts\run_e2e_lectura.ps1 -Imagen ghcr.io/asistente-agentico/illari:dev-0.7.2
#>

param(
    [string]$Suite        = "tests/e2e_lectura.yaml",
    [string]$MasterSecret = $env:MASTER_SECRET,
    [string]$Imagen       = "ghcr.io/asistente-agentico/illari:dev-0.7.1",
    [switch]$Dev
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -- Rutas ------------------------------------------------------------------
$repoRaiz = Split-Path -Parent $PSScriptRoot

# -- Leer MASTER_SECRET desde .env si no viene por parametro/env ------------
if (-not $MasterSecret) {
    $envFile = Join-Path $repoRaiz ".env"
    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {
            if ($_ -match "^\s*(export\s+)?MASTER_SECRET\s*=\s*(.+)$") {
                $MasterSecret = $Matches[2].Trim().Trim('"').Trim("'")
            }
        }
    }
}

$suiteAbs = Join-Path $repoRaiz $Suite

if (-not (Test-Path $suiteAbs)) {
    Write-Error "Suite no encontrada: $suiteAbs"
    exit 1
}

if (-not $MasterSecret) {
    Write-Error "MASTER_SECRET no definido. Pasalo con -MasterSecret o en el archivo .env."
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
Write-Host "=== Illari E2E lectura completo (MK+MV+M1+M2) ==="
Write-Host "Suite  : $suiteName v$version"
Write-Host "Modo   : $modo"
Write-Host "Imagen : $Imagen"
Write-Host "Output : $outFile"
Write-Host ""

# -- Fase previa: limpiar qdrant_data para partida limpia ------------------
Write-Host "[0/1] Limpiando qdrant_data/ para partida limpia..."
$qdrantDir = Join-Path $repoRaiz "qdrant_data"
if (Test-Path $qdrantDir) {
    Remove-Item -Recurse -Force $qdrantDir
    Write-Host "  Eliminado: $qdrantDir"
} else {
    Write-Host "  qdrant_data/ no existe, nada que limpiar."
}
Write-Host ""

# -- Comando shell dentro del contenedor ------------------------------------
# Fases dentro del contenedor (todo en un solo docker run):
#   A) instalar fastembed
#   B) arrancar MK (puerto 8003)
#   C) arrancar MV (puerto 8002, apunta a MK)
#   D) esperar MV listo (health check con reintentos)
#   E) correr M1 sin --dev (embebe y sube a Qdrant via MV)
#   F) detener MK y MV
#   G) correr M2 pytest

$pytestFlags = if ($Dev) { "-v -s -m e2e" } else { "-v -m e2e" }
$verboseVal  = if ($Dev) { "1" } else { "0" }

$cmd = @"
set -e
pip install fastembed -q 2>/dev/null

echo '[A] Copiando cliente a tmpfs nativo (Qdrant embedded requiere fs nativo, no mount NTFS)...'
cp -r /cliente/minera /tmp/minera

echo '[A.1] Creando coleccion Qdrant antes de arrancar MV...'
python3 -c 'from qdrant_client import QdrantClient; from qdrant_client.http.models import VectorParams, Distance; c=QdrantClient(path="/tmp/minera/qdrant_data"); ex=[x.name for x in c.get_collections().collections]; c.create_collection("chunks",vectors_config=VectorParams(size=384,distance=Distance.COSINE)) if "chunks" not in ex else None; print("  coleccion chunks lista"); c.close()'

echo '[A.2] Pre-descargando modelo embeddings (para arranque rapido de MV)...'
python3 -c 'from fastembed import TextEmbedding; TextEmbedding(model_name="sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"); print("  modelo listo")'

echo '[B] Arrancando MK (puerto 8003)...'
MASTER_SECRET=$MasterSecret uvicorn mk.api.main:app --host 0.0.0.0 --port 8003 &
MK_PID=`$!
sleep 3

echo '[C] Arrancando MV (puerto 8002)...'
CLIENTE_DIR=/tmp/minera MK_URL=http://localhost:8003 MA_JWKS_URL=http://localhost:8001/jwks uvicorn mv.api.main:app --host 0.0.0.0 --port 8002 &
MV_PID=`$!

echo '[D] Esperando MV listo...'
for i in 1 2 3 4 5 6 7 8 9 10; do
    sleep 3
    STATUS=`$(python3 -c 'import httpx; r=httpx.get("http://localhost:8002/health",timeout=2); print(r.status_code)' 2>/dev/null || echo 0)
    if [ "`$STATUS" = "200" ] || [ "`$STATUS" = "503" ]; then
        echo "  MV respondiendo (status `$STATUS)"
        break
    fi
    echo "  Intento `$i/10 - MV aun no listo"
done

echo '[E] Corriendo M1 embed...'
MV_URL=http://localhost:8002 MINERA_DB_PATH=/tmp/minera/datos/minera.duckdb python -m m1.core.orquestador.cli ejecutar --config /tmp/minera/configuracion --schemas /app/configuracion/schemas --medallon /tmp/minera/modelos --profiles-dir /tmp/minera/modelos --raiz /tmp/minera
M1_EXIT=`$?

echo '[F] Deteniendo MK y MV...'
kill `$MV_PID `$MK_PID 2>/dev/null || true
sleep 2
kill -9 `$MV_PID `$MK_PID 2>/dev/null || true
sleep 1

if [ `$M1_EXIT -ne 0 ]; then
    echo "FAILED M1 embed (exit `$M1_EXIT)"
    exit `$M1_EXIT
fi

echo '[G] Corriendo M2 pytest...'
ILLARI_E2E_SUITE=/tmp/minera/tests/e2e_lectura.yaml ILLARI_E2E_CLIENTE=/tmp/minera MASTER_SECRET=$MasterSecret ILLARI_E2E_VERBOSE=$verboseVal python -m pytest /app/tests/e2e/ $pytestFlags
"@

# -- Escribir script a archivo temporal sin BOM (evita bug quoting PS1->Docker)
$tempScript = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "illari_e2e_inner.sh")
$utf8NoBOM = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($tempScript, $cmd, $utf8NoBOM)

# -- Ejecutar en Docker -----------------------------------------------------
Write-Host "[1/1] Ejecutando pipeline completo en Docker..."
Write-Host ""

$dockerArgs = @(
    "run", "--rm",
    "-v", "${repoRaiz}:/cliente/minera",
    "-v", "${tempScript}:/tmp/illari_e2e_inner.sh"
)
if ($devMount.Count -gt 0) {
    $dockerArgs += $devMount
}
$dockerArgs += @(
    "--entrypoint", "sh",
    $Imagen,
    "/tmp/illari_e2e_inner.sh"
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
