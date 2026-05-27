# Datamart M_OT_EN_CURSO

**Ámbito**: mantención

OT pertenecientes a la semana en curso que aún no se han cerrado (sin marca de cumplimiento).

## Preguntas que responde

### ¿Cuáles son las Órdenes de Trabajo que actualmente están siendo ejecutadas?

```sql
SELECT
    orden_nro,
    ot_texto_breve,
    equipo_denom,
    planta_canon,
    inicio_programado,
    anio,
    semana_nro
FROM M_OT_EN_CURSO
WHERE (cumpl_prog IS NULL OR cumpl_prog = 0)
  AND anio = :anio_actual
  AND semana_nro = :semana_actual
ORDER BY inicio_programado;
```

### ¿Qué trabajo involucran las Órdenes de Trabajo X, Y, Z?

```sql
SELECT
    orden_nro,
    ot_texto_breve,
    equipo_denom,
    ubicacion_tecnica,
    planta_canon,
    tipo_equipo,
    inicio_programado,
    hh_planificadas
FROM M_OT_EN_CURSO
WHERE orden_nro IN (:orden_x, :orden_y, :orden_z)
ORDER BY orden_nro;
```

---

## Hechos

| Hecho | Campo | Tipo | Descripción |
|---|---|---|---|
| Indicador de no-cumplimiento aún | `cumpl_prog` | int | NULL o 0 — la OT aún no se ha cerrado (filtro fundamental) |
| Horas-hombre planificadas | `hh_planificadas` | numeric | Horas-hombre programadas para la OT |
| Fecha programada | `inicio_programado` | date | Fecha en que la OT debió iniciar (dentro de la semana en curso) |

---

## Dimensiones

### Dimensiones (entidades de negocio con hub propio)

| Dimensión | Campo | Hub asociado | Descripción |
|---|---|---|---|
| Orden de trabajo | `orden_nro`, `ot_texto_breve` | `H_ORDEN_TRABAJO` | Número de OT y texto breve |
| Máquina de control de polvo | `equipo_denom`, `ubicacion_tecnica` | `H_MAQUINA_CONTROL_POLVO` | Máquina objeto de la OT |
| Planta | `planta_canon` | `H_PLANTA` | Planta donde está la máquina |
| Tipo de equipo | `tipo_equipo` | `H_TIPO_EQUIPO_CTRL` | HDP / CDP / EPZ / VEX / VIN / PVA / PVM / PTV / PIN / DAM |
| Semana | `semana_nro` | `H_SEMANA` | Semana en curso (filtro fundamental) |
| Ámbito | `ambito` | `H_AMBITO` | mantencion (fijo) |

### Atributos del hecho (viven en satélites)

| Atributo | Campo | Satélite origen | Descripción |
|---|---|---|---|
| Familia de equipo | `familia` | `S_MAQCTRL_DESCR.familia` | renovacion_aire / abatidor_polvo |

### Atributos derivados de dimensión

| Atributo | Campo | Derivado de | Descripción |
|---|---|---|---|
| Año | `anio` | `S_SEMANA_DESCR.fecha_inicio` | Año calendario |

---

## Mapeo Hoja del Programa ↔ Planta canónica

| Hoja del Excel | `H_PLANTA.planta_canon` | Notas |
|---|---|---|
| `Chancado Fino` | Chancado Secundario y Terciario · Chancado Terciario y Cuaternario | Cabecera en fila 3 |
| `Molienda` | Molienda SAG | Cabecera en fila 2 |
| `Chancado Primario` | Prechancado · Nodo 3500 | Cabecera en fila 2 |
| `Programa` (fallback) | CDM Linea 1 · CDM Linea 2 | Solo estas plantas |

---

## Estructuras del Data Vault que dan origen al datamart

### Hubs

- `H_ORDEN_TRABAJO` — OT en ejecución
- `H_MAQUINA_CONTROL_POLVO` — máquina objeto de la OT
- `H_PLANTA` — planta
- `H_SEMANA` — semana en curso
- `H_TIPO_EQUIPO_CTRL` — tipo de equipo

### Links

- `L_OT_MAQCTRL` — asocia OT con máquina y semana

### Satélites

- `S_OT_DESCR` — texto_breve
- `S_OT_PROGRAMACION` — inicio_programado
- `S_OT_EJECUCION` — cumpl_prog (filtro: NULL o 0), hh_planificadas
- `S_MAQCTRL_DESCR` — denominación, tipo y familia
- `S_PLANTA_DESCR` — planta_canon

### PIT y Bridge

- `PIT_OT` — pre-resuelve los sats de la OT en un solo lookup
- `BR_MANTENCION_SEMANAL` — **Bridge principal del datamart**. Denormaliza OT + máquina + planta + semana

---

## Correlación dato del datamart → tabla del Data Vault → origen físico

| Campo del datamart | Tabla origen en el DV | Archivo Excel | Hoja | Coordenada / Rango |
|---|---|---|---|---|
| `orden_nro` (Chancado Fino) | `H_ORDEN_TRABAJO.orden_nro` (BK) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino | Columna **B "Orden"** (B4:B348) |
| `orden_nro` (Molienda) | `H_ORDEN_TRABAJO.orden_nro` | Programa_Semana_21_2026_Ventilacion.xlsx | Molienda | Columna **B "Orden"** (B3:B196) |
| `orden_nro` (Chancado Primario) | `H_ORDEN_TRABAJO.orden_nro` | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Primario | Columna **B "Orden"** (B3:B57) |
| `orden_nro` (fallback CDM L1 y L2) | `H_ORDEN_TRABAJO.orden_nro` | Programa_Semana_21_2026_Ventilacion.xlsx | Programa | Columna **B "Orden"** (B2:B100) — solo CDM L1 y L2 |
| `ot_texto_breve` | `S_OT_DESCR.texto_breve` (vía `PIT_OT`) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Columna **E "Txt.brv."** |
| `equipo_denom` | `S_MAQCTRL_DESCR.denominacion` (vía `BR_MANTENCION_SEMANAL`) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino (fila 3) · Molienda (fila 2) · Chancado Primario (fila 2) | Columna **A "Denominación"** |
| `ubicacion_tecnica` | `H_MAQUINA_CONTROL_POLVO.ubicacion_tecnica` (BK) | Programa_Semana_21_2026_Ventilacion.xlsx | Programa | Columna **G "Ubicación técnica"** |
| `tipo_equipo` | `S_MAQCTRL_DESCR.tipo_equipo` (derivado) | Programa_Semana_21_2026_Ventilacion.xlsx | Programa | Derivado del 5° segmento de col G — HDP / CDP / EPZ / VEX / VIN / PVA / PVM / PTV / PIN / DAM |
| `familia` | `S_MAQCTRL_DESCR.familia` (derivado) | Programa_Semana_21_2026_Ventilacion.xlsx | Programa | Derivado del 4° segmento de col G: `SVE` → renovacion_aire, `SCP` → abatidor_polvo |
| `planta_canon` | `S_PLANTA_DESCR.nombre_canon` (vía `BR_MANTENCION_SEMANAL`) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Inferida por la hoja en que aparece la OT |
| `inicio_programado` | `S_OT_PROGRAMACION.inicio_programado` (vía `PIT_OT`) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Columna **H "FechaInicMásTmp"** |
| `cumpl_prog` | `S_OT_EJECUCION.cumpl_prog` | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Columna **O "CumplProg"** — filtro: NULL o 0 |
| `hh_planificadas` (Molienda, Chancado Primario) | `S_OT_EJECUCION.hh_planificadas` | Programa_Semana_21_2026_Ventilacion.xlsx | Molienda · Chancado Primario | Columna **I "HorasHombreProg."** |
| `hh_planificadas` (Chancado Fino) | `S_OT_EJECUCION.hh_planificadas` | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino | Columna **I "Trabajo"** (nombre distinto en esta hoja) |
| `anio` | `BR_MANTENCION_SEMANAL` (derivado de `S_SEMANA_DESCR`) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Derivado: semana 21 de 2026 (celda B1) |
| `semana_nro` | `BR_MANTENCION_SEMANAL` (denormalizado desde `S_SEMANA_DESCR`) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino | Celda **B1** "Semana del Programa = 21" |
| `ambito` | `BR_MANTENCION_SEMANAL` (constante por diseño) | — | — | Valor fijo `mantencion` asignado durante el ETL |
