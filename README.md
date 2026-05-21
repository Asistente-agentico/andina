# Minera — Configuración cliente

Configuración del Asistente Virtual para el caso **Minera**: monitoreo de concentración
de polvo respirable en puntos de medición de faena. Responde 4 preguntas de negocio
sobre mediciones ambientales bajo DS 594.

Compatible con: `asistente-agentico/diseno v0.5.0+`

> **Este repositorio es del equipo de servicio.** El cliente nunca lo ve.
> La configuración y los modelos de transformación viajan dentro de la imagen Docker.

---

## Estructura

```
configuracion/
  dominio.yaml         — dimensiones de gobernanza y configuración del dominio
  fuentes.yaml         — fuentes de datos del lakehouse del cliente
  aterrizaje.yaml      — configuración de la zona de aterrizaje
  reglas/
    reglas.yaml        — 4 reglas (P00001–P00004), una por pregunta de negocio
  consultas/
    P000XX_M000XX.sql  — consulta al mart gold correspondiente (columnas explícitas)
  plantillas/
    P000XX_M000XX.txt  — texto de respuesta con variables {campo}

modelos/               — capa de transformación (interna; no expuesta al cliente)
  dbt_project.yml
  models/
    bronce/            — staging desde la zona de aterrizaje del cliente
    silver/            — entidades, relaciones y detalles (append-only)
    oro/               — marts M00001–M00004 consumidos por las reglas
  macros/              — utilidades de hashing y transformación
  instantaneos/        — historial por fuente (una instantánea por planilla)
  semillas/            — tablas de referencia (semáforo de límites)

analisis/
  preguntas.md         — contexto de negocio: preguntas, reglas y decisiones de diseño

scripts/
  preparar_landing.py    — extrae hojas del xlsx en formato ancho (etiqueta, column01…columnNN)
  run_e2e_lectura.ps1    — E2E completo lectura: MK+MV+M1 embed+M2 pytest en un contenedor
  run_e2e_lectura.sh     — equivalente bash de run_e2e_lectura.ps1 (Linux/macOS)
  run_e2e_escritura.ps1  — E2E completo escritura: MK+MV+M1 embed, valida chunks en Qdrant
  run_e2e_escritura.sh   — equivalente bash de run_e2e_escritura.ps1 (Linux/macOS)
  run_e2e_m3.ps1         — E2E reportes M3: pytest tests/e2e_m3/ sin MK/MV/Qdrant
  run_e2e_m3.sh          — equivalente bash de run_e2e_m3.ps1 (Linux/macOS)
  check_marts.py         — diagnóstico: cuenta filas en marts gold y silver
  check_snapshots.py     — diagnóstico: cuenta filas y columnas en los snapshots

tests/
  e2e_lectura.yaml        — suite E2E lectura (M2): 4 perfiles, 11 escenarios polvo respirable
  e2e_escritura.yaml      — suite E2E escritura (M1→MV): conteo, gobernanza, PII, cifrado
  e2e_m3_reportes.yaml    — suite E2E reportes (M3): concentracion_anual, 4 perfiles, 13 escenarios

datos/                 — gitignoreado (PII + datos del cliente; solo en ambiente local)
qdrant_data/           — gitignoreado (vector store local generado por chunker --embed)
```

---

## Lo que recibe el cliente

| Artefacto | Descripción |
|---|---|
| Imagen Docker | `ghcr.io/asistente-agentico/minera:vX.Y.Z` |
| `docker-compose.yml` | Levanta el servicio; referencia la imagen y el `.env` |
| `.env.example` | Variables de conexión al lakehouse; el cliente llena sus credenciales |

El cliente no ve ni `configuracion/`, ni `modelos/`, ni ninguna tecnología interna.

> Artefactos de despliegue (`Dockerfile`, `docker-compose.yml`, `.env.example`) pendientes.
> Se generan al cablear el pipeline de build en el sprint de deployment.

---

## Variables de entorno del cliente (`.env`)

```
DB_TIPO=duckdb            # duckdb | postgresql | bigquery | athena | ...
DB_HOST=
DB_PUERTO=
DB_USUARIO=
DB_CLAVE=
DB_NOMBRE=
ASISTENTE_PUERTO=8000
```

El contenedor usa estas variables para configurar la conexión al lakehouse internamente.

---

## Desarrollo (equipo de servicio)

### Prerrequisitos

- Python 3.12+
- dbt-core 1.11+ con el adapter del lakehouse del cliente (`dbt-duckdb`, `dbt-bigquery`, etc.)
- Docker

### Linter de configuración

```bash
# Desde el repo del producto (diseno)
python -m scripts.lint_configuracion /ruta/a/minera/configuracion/reglas/reglas.yaml
```

### Pipeline de preparación (desde el xlsx del cliente)

El pipeline convierte la planilla Excel de mediciones en chunks semánticos indexados
en Qdrant. Ejecutar desde la imagen del producto o con las dependencias instaladas:

```bash
# 1. xlsx → CSVs en formato ancho (una fila por atributo, columnas column01…columnNN)
python scripts/preparar_landing.py --raiz /ruta/a/minera

# 2. CSVs → DuckDB (zona de aterrizaje)
python scripts/init_duckdb.py --raiz /ruta/a/minera

# 3. dbt: seeds → snapshots → modelos
cd modelos
dbt seed      # semillas (semáforo de límites, alias de personas)
dbt snapshot  # captura histórico desde landing
dbt run       # construye bronce → silver → oro (M00001–M00004)

# 4. Chunker: marts gold → chunks cifrados → Qdrant
python -m core.agentes.chunker --raiz /ruta/a/minera --embed
```

Requiere `modelos/profiles.yml` local (gitignoreado) y la variable de entorno
`MASTER_SECRET` para el cifrado de chunks.

### Modelos de transformación (solo)

```bash
cd modelos
dbt deps                  # instalar dependencias
dbt snapshot              # capturar histórico desde landing
dbt run                   # construir bronce → silver → oro
dbt test                  # validar constraints y freshness
```

Requiere `modelos/profiles.yml` local (gitignoreado). Ver `.env.example` como referencia.

### Tests E2E

Tres suites complementarias, cada una con su par de scripts (`.ps1` Windows / `.sh` Linux·macOS).
Los pipelines son **autocontenidos**: levantan solo los servicios que necesitan dentro del
contenedor. No requieren servicios externos en ejecución.

#### Suite lectura — `run_e2e_lectura.ps1` / `.sh`

Valida el pipeline RAG completo M1→MV→M2:
- M1 embebe los marts gold y sube los chunks cifrados a Qdrant via MV.
- M2 responde consultas del usuario consultando MV (búsqueda vectorial + gobernanza).

**Prerequisito**: `datos/minera.duckdb` presente (`dbt seed && dbt run`).

```powershell
.\scripts\run_e2e_lectura.ps1 -Dev
# -Dev: monta tests/ local de Illari + verbose pytest
```
```bash
bash scripts/run_e2e_lectura.sh --dev
```

11 escenarios: 5 de negocio (P1×2 perfiles + P2 + P3 + P4), 2 de autenticación,
1 de payload inválido, 1 sin match semántico, 2 de gobernanza (acceso denegado).

#### Suite escritura — `run_e2e_escritura.ps1` / `.sh`

Valida el pipeline de escritura M1→MV: conteo de chunks, gobernanza, PII y cifrado.

```powershell
.\scripts\run_e2e_escritura.ps1 -Dev
```
```bash
bash scripts/run_e2e_escritura.sh --dev
```

#### Suite reportes M3 — `run_e2e_m3.ps1` / `.sh`

Valida el módulo de reportes estructurados M3: gobernanza por planta, parámetros
opcionales y autenticación. Lee directamente desde DuckDB; no requiere Qdrant ni
`MASTER_SECRET`.

**Prerequisito**: `datos/minera.duckdb` presente (`dbt seed && dbt run`).

```powershell
.\scripts\run_e2e_m3.ps1 -Dev
```
```bash
bash scripts/run_e2e_m3.sh --dev
```

13 escenarios: 2 de autenticación, 1 de listado, 1 de reporte inexistente,
4 de gobernanza por planta (acceso completo y restringido), 4 de parámetro `anio`
(con y sin filtro, dos perfiles).

#### Resultado

Los tres pares de scripts guardan el resultado en:

```
tests/results/{suite}-v{version}[-dev]-{timestamp}.txt
```

El directorio `tests/results/` está gitignoreado.

#### Notas de implementación

Los scripts montan el repo como bind-mount pero copian los datos del cliente a
`/tmp/minera` (tmpfs nativo Linux) antes de arrancar Qdrant. Esto evita errores
de bloqueo de archivos (`portalocker` falla sobre NTFS/9P de WSL2).

El modelo de embeddings (`paraphrase-multilingual-MiniLM-L12-v2`) se pre-descarga
en el contenedor antes de arrancar MV para garantizar que el health-check pase
sin agotar los reintentos.

---

## Contexto de negocio

Ver [`analisis/preguntas.md`](analisis/preguntas.md) — preguntas del cliente, reglas,
marts y decisiones de diseño del caso.
