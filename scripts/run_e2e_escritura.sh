#!/usr/bin/env bash
# run_e2e_escritura.sh — Ejecuta el pipeline completo M1→MV y valida la salida.
#
# Fases:
#   1. Borrar qdrant_data/ (partida limpia — embeddings se regeneran desde cero).
#   2. Docker: iniciar MV + ejecutar M1 CLI (dbt → chunker → cifrado → upsert Qdrant).
#   3. Local: pytest valida chunks_generados.json contra e2e_escritura.yaml.
#
# Uso:
#   bash scripts/run_e2e_escritura.sh
#   bash scripts/run_e2e_escritura.sh tests/e2e_escritura.yaml
#
# Variables de entorno:
#   MASTER_SECRET  — secreto de cifrado (obligatorio; también se puede poner en .env)
#   ILLARI_TAG     — tag de la imagen Docker (default: dev-0.6.6)
#
# Prerequisito: datos/minera.duckdb con semillas cargadas (dbt seed ejecutado).

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuración
# ---------------------------------------------------------------------------
IMAGEN_BASE="ghcr.io/asistente-agentico/illari"
IMAGEN="${IMAGEN_BASE}:${ILLARI_TAG:-dev-0.6.6}"

REPO_RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
SUITE_REL="tests/e2e_escritura.yaml"

for arg in "$@"; do
    case "$arg" in
        *.yaml|*.yml) SUITE_REL="$arg" ;;
        *) echo "Argumento desconocido: $arg" >&2; exit 1 ;;
    esac
done

SUITE_ABS="${REPO_RAIZ}/${SUITE_REL}"

# ---------------------------------------------------------------------------
# Leer MASTER_SECRET (env > .env > error)
# ---------------------------------------------------------------------------
if [[ -z "${MASTER_SECRET:-}" ]]; then
    ENV_FILE="${REPO_RAIZ}/.env"
    if [[ -f "$ENV_FILE" ]]; then
        MASTER_SECRET=$(grep -E '^\s*(export\s+)?MASTER_SECRET\s*=' "$ENV_FILE" \
            | head -1 | sed -E 's/^\s*(export\s+)?MASTER_SECRET\s*=\s*//' | tr -d '"'"'" | xargs)
    fi
fi

if [[ -z "${MASTER_SECRET:-}" ]]; then
    echo "Error: MASTER_SECRET no definido." >&2
    echo "Pásalo como variable de entorno o agrégalo al archivo .env del repo." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Validar suite y dependencias
# ---------------------------------------------------------------------------
if [[ ! -f "$SUITE_ABS" ]]; then
    echo "Error: suite no encontrada: $SUITE_ABS" >&2
    exit 1
fi

if [[ ! -f "${REPO_RAIZ}/datos/minera.duckdb" ]]; then
    echo "Error: datos/minera.duckdb no encontrado." >&2
    echo "Ejecuta 'dbt seed' y 'dbt run' en modelos/ antes de correr esta suite." >&2
    exit 1
fi

# Localizar test_pipeline.py en el repo hermano Illari
ILLARI_TESTS="$(dirname "$REPO_RAIZ")/Illari/tests"
TEST_PIPELINE="${ILLARI_TESTS}/e2e_escritura/test_pipeline.py"
if [[ ! -f "$TEST_PIPELINE" ]]; then
    echo "Error: test_pipeline.py no encontrado en ${TEST_PIPELINE}" >&2
    echo "Verifica que el repo Illari esté en $(dirname "$REPO_RAIZ")/Illari" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Info
# ---------------------------------------------------------------------------
TS=$(date +%Y%m%d-%H%M%S)
OUT_DIR="${REPO_RAIZ}/tests/results"
OUT_FILE="${OUT_DIR}/e2e_escritura-${TS}.txt"
mkdir -p "$OUT_DIR"

echo ""
echo "=== Illari E2E escritura — minera ==="
echo "Suite  : ${SUITE_ABS}"
echo "Imagen : ${IMAGEN}"
echo "Output : ${OUT_FILE}"
echo ""

# ---------------------------------------------------------------------------
# Fase 1 — Borrar qdrant_data/ (partida limpia)
# ---------------------------------------------------------------------------
echo "[1/3] Limpiando qdrant_data/..."
QDRANT_DIR="${REPO_RAIZ}/qdrant_data"
if [[ -d "$QDRANT_DIR" ]]; then
    rm -rf "$QDRANT_DIR"
    echo "  Eliminado: ${QDRANT_DIR}"
else
    echo "  No existe qdrant_data/, nada que limpiar."
fi
echo ""

# ---------------------------------------------------------------------------
# Fase 2 — Docker: MV (background) + M1 CLI
# ---------------------------------------------------------------------------
echo "[2/3] Ejecutando pipeline en Docker..."
echo "  Imagen: ${IMAGEN}"
echo ""

PIPELINE_CMD='
pip install fastembed -q 2>/dev/null

export CONFIGURACION_DIR=/cliente/minera/configuracion
export MV_URL=http://localhost:8002
export MINERA_DB_PATH=/cliente/minera/datos/minera.duckdb

echo "  Iniciando MV en :8002..."
uvicorn mv.api.main:app --host 0.0.0.0 --port 8002 --log-level warning &
MV_PID=$!

TIMEOUT=30
ELAPSED=0
until curl -sf http://localhost:8002/health > /dev/null 2>&1; do
    sleep 1
    ELAPSED=$((ELAPSED+1))
    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        echo "Error: MV no respondió en ${TIMEOUT}s" >&2
        kill "$MV_PID" 2>/dev/null || true
        exit 1
    fi
done
echo "  MV listo. Ejecutando pipeline M1..."

python -m m1.core.orquestador.cli ejecutar \
    --config /cliente/minera/configuracion \
    --schemas /app/configuracion/schemas \
    --medallon /cliente/minera/modelos \
    --profiles-dir /cliente/minera/modelos \
    --raiz /cliente/minera
EXIT_M1=$?

kill "$MV_PID" 2>/dev/null || true
exit $EXIT_M1
'

docker pull "${IMAGEN}"
echo ""

docker run --rm \
    -v "${REPO_RAIZ}:/cliente/minera" \
    -e "MASTER_SECRET=${MASTER_SECRET}" \
    --entrypoint sh \
    "${IMAGEN}" \
    -c "${PIPELINE_CMD}" \
    | tee -a "${OUT_FILE}"

DOCKER_EXIT="${PIPESTATUS[0]}"

if [[ $DOCKER_EXIT -ne 0 ]]; then
    echo ""
    echo "FAILED pipeline Docker (exit ${DOCKER_EXIT}) — ver: ${OUT_FILE}"
    exit "$DOCKER_EXIT"
fi

echo ""
echo "  Pipeline completado. chunks_generados.json generado."
echo ""

# ---------------------------------------------------------------------------
# Fase 3 — Validación local con pytest
# ---------------------------------------------------------------------------
echo "[3/3] Validando chunks_generados.json con pytest..."
echo ""

ILLARI_E2E_ESCRITURA="${SUITE_ABS}" \
ILLARI_E2E_RAIZ="${REPO_RAIZ}" \
python3 -m pytest "${TEST_PIPELINE}" -v -m e2e \
    --rootdir="${ILLARI_TESTS}/.." \
    | tee -a "${OUT_FILE}"

PYTEST_EXIT="${PIPESTATUS[0]}"

echo ""
if [[ $PYTEST_EXIT -eq 0 ]]; then
    echo "PASSED — resultado guardado en: ${OUT_FILE}"
else
    echo "FAILED (exit ${PYTEST_EXIT}) — resultado guardado en: ${OUT_FILE}"
fi

exit "$PYTEST_EXIT"
