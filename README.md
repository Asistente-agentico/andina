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
  domain.yaml          — dimensiones de gobernanza y configuración del dominio
  fuentes.yaml         — fuentes de datos del lakehouse del cliente
  landing.yaml         — configuración de la zona de aterrizaje
  reglas/
    reglas.yaml        — 4 reglas (P00001–P00004), una por pregunta de negocio
  sql/
    P000XX_M000XX.sql  — consulta al mart gold correspondiente (columnas explícitas)
  templates/
    P000XX_M000XX.txt  — texto de respuesta con variables {campo}

modelos/               — capa de transformación (interna; no expuesta al cliente)
  dbt_project.yml
  models/
    bronce/            — staging desde la zona de aterrizaje del cliente
    silver/            — entidades, relaciones y detalles (append-only)
    oro/               — marts M00001–M00004 consumidos por las reglas
  macros/              — utilidades de hashing y transformación
  snapshots/           — historial por fuente (una snapshot por planilla)
  seeds/               — tablas de referencia (semáforo de límites)

analisis/
  preguntas.md         — contexto de negocio: preguntas, reglas y decisiones de diseño

datos/                 — gitignoreado (PII + datos del cliente; solo en ambiente local)
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

### Modelos de transformación

```bash
cd modelos
dbt deps                  # instalar dependencias
dbt snapshot              # capturar histórico desde landing
dbt run                   # construir bronce → silver → oro
dbt test                  # validar constraints y freshness
```

Requiere `modelos/profiles.yml` local (gitignoreado). Ver `.env.example` como referencia.

---

## Contexto de negocio

Ver [`analisis/preguntas.md`](analisis/preguntas.md) — preguntas del cliente, reglas,
marts y decisiones de diseño del caso.
