#!/usr/bin/env bash
# run_e2e_m3.sh — Ejecuta la suite E2E de reportes M3 (concentracion_anual).
#
# Equivalente bash de run_e2e_m3.ps1 (para entornos Linux/macOS).
# La imagen monolítica contiene M3 y MA — docker pull los descarga todos.
#
# Uso:
#   bash scripts/run_e2e_m3.sh                                     # modo normal
#   bash scripts/run_e2e_m3.sh --dev                               # verbose
#   bash scripts/run_e2e_m3.sh tests/e2e_m3_reportes.yaml          # suite explícita
#   bash scripts/run_e2e_m3.sh tests/e2e_m3_reportes.yaml --dev    # suite + verbose
#
# Variables de entorno:
#   ILLARI_TAG  — tag de la imagen Docker (default: dev-0.7.1)
#
# No requiere MASTER_SECRET (M3 no usa MV ni Qdrant).
# Prerequisito: datos/minera.duckdb presente (dbt seed && dbt run).

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuración
# ---------------------------------------------------------------------------
IMAGEN_BASE="ghcr.io/asistente-agentico/illari"
IMAGEN="${IMAGEN_BASE}:${ILLARI_TAG:-dev-0.7.1}"

REPO_RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
SUITE_REL="tests/e2e_m3_reportes.yaml"
DEV=0

# ---------------------------------------------------------------------------
# Parsear argumentos
# ---------------------------------------------------------------------------
for arg in "$@"; do
    case "$arg" in
        --dev|-d)   DEV=1 ;;
        *.yaml|*.yml) SUITE_REL="$arg" ;;
        *) echo "Argumento desconocido: $arg" >&2; exit 1 ;;
    esac
done

SUITE_ABS="${REPO_RAIZ}/${SUITE_REL}"

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

# ---------------------------------------------------------------------------
# Extraer nombre y versión del YAML de suite
# ---------------------------------------------------------------------------
SUITE_NAME="$(basename "$SUITE_REL" .yaml)"
SUITE_VERSION=$(python3 -c "
try:
    import yaml
    d = yaml.safe_load(open('${SUITE_ABS}'))
    print(d.get('version', 'sin-version'))
except Exception:
    print('sin-version')
" 2>/dev/null || echo "sin-version")

# ---------------------------------------------------------------------------
# Nombre del archivo de resultado
# ---------------------------------------------------------------------------
TS=$(date +%Y%m%d-%H%M%S)
DEV_SUFIJO=""
[[ $DEV -eq 1 ]] && DEV_SUFIJO="-dev"
OUT_DIR="${REPO_RAIZ}/tests/results"
OUT_FILE="${OUT_DIR}/${SUITE_NAME}-v${SUITE_VERSION}${DEV_SUFIJO}-${TS}.txt"
mkdir -p "$OUT_DIR"

# ---------------------------------------------------------------------------
# Info
# ---------------------------------------------------------------------------
MODO=$( [[ $DEV -eq 1 ]] && echo "dev (verbose)" || echo "normal" )
echo ""
echo "=== Illari E2E M3 (reportes) — minera ==="
echo "Suite  : ${SUITE_NAME} v${SUITE_VERSION}"
echo "Modo   : ${MODO}"
echo "Imagen : ${IMAGEN}"
echo "Output : ${OUT_FILE}"
echo ""

# ---------------------------------------------------------------------------
# 1. Descargar imagen
# ---------------------------------------------------------------------------
echo "[1/2] docker pull ${IMAGEN}"
docker pull "${IMAGEN}"
echo ""

# ---------------------------------------------------------------------------
# 2. Ejecutar suite E2E M3
# ---------------------------------------------------------------------------
echo "[2/2] Ejecutando suite E2E M3…"

PYTEST_FLAGS="-v -m e2e"
[[ $DEV -eq 1 ]] && PYTEST_FLAGS="-v -s -m e2e"
VERBOSE_VAL=$( [[ $DEV -eq 1 ]] && echo "1" || echo "0" )

CMD="python -m pytest /app/tests/e2e_m3/ ${PYTEST_FLAGS}"

EXTRA_MOUNTS=()
if [[ $DEV -eq 1 ]]; then
    ILLARI_TESTS="$(dirname "$REPO_RAIZ")/Illari/tests"
    if [[ -d "$ILLARI_TESTS" ]]; then
        EXTRA_MOUNTS=(-v "${ILLARI_TESTS}:/app/tests")
        echo "Tests  : ${ILLARI_TESTS} (montado en /app/tests)"
    else
        echo "Tests  : usando tests embebidos en la imagen (${ILLARI_TESTS} no encontrado)"
    fi
fi

docker run --rm \
    -v "${REPO_RAIZ}:/cliente/minera" \
    "${EXTRA_MOUNTS[@]+"${EXTRA_MOUNTS[@]}"}" \
    -e "ILLARI_E2E_M3=/cliente/minera/${SUITE_REL}" \
    -e "ILLARI_E2E_CLIENTE=/cliente/minera" \
    -e "ILLARI_E2E_VERBOSE=${VERBOSE_VAL}" \
    --entrypoint sh \
    "${IMAGEN}" \
    -c "${CMD}" \
    | tee "${OUT_FILE}"

EXIT_CODE="${PIPESTATUS[0]}"

echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
    echo "PASSED — resultado guardado en: ${OUT_FILE}"
else
    echo "FAILED (exit ${EXIT_CODE}) — resultado guardado en: ${OUT_FILE}"
fi

exit "$EXIT_CODE"
