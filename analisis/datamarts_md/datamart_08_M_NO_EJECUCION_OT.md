# Datamart M_NO_EJECUCION_OT

**Ámbito**: mantención

## Preguntas que responde

### ¿Por qué la máquina X no tuvo mantención?

```sql
SELECT
    equipo_denom,
    ubicacion_tecnica,
    orden_nro,
    ot_texto_breve,
    inicio_programado,
    motivo_no_ejecucion,
    fecha_reprogramacion,
    planta_canon,
    anio,
    semana_nro
FROM M_NO_EJECUCION_OT
WHERE equipo_denom ILIKE :maquina
  AND cumpl_prog = 0
ORDER BY anio DESC, semana_nro DESC;
```

### ¿En qué fecha se reprogramó la mantención?

```sql
SELECT
    orden_nro,
    equipo_denom,
    ot_texto_breve,
    inicio_programado AS fecha_original,
    motivo_no_ejecucion,
    fecha_reprogramacion
FROM M_NO_EJECUCION_OT
WHERE (orden_nro = :orden_nro OR equipo_denom ILIKE :maquina)
  AND fecha_reprogramacion IS NOT NULL;
```

### ¿Cuáles son las máquinas que no han sido mantenidas en la fecha que se programó?

```sql
SELECT
    equipo_denom,
    ubicacion_tecnica,
    tipo_equipo,
    familia,
    planta_canon,
    orden_nro,
    ot_texto_breve,
    inicio_programado AS fecha_programada,
    motivo_no_ejecucion,
    fecha_reprogramacion,
    anio,
    semana_nro
FROM M_NO_EJECUCION_OT
WHERE cumpl_prog = 0
ORDER BY anio DESC, semana_nro DESC, planta_canon, equipo_denom;
```

---

## Hechos

| Hecho | Campo | Tipo | Descripción |
|---|---|---|---|
| Indicador de cumplimiento | `cumpl_prog` | int | 0 = no ejecutada, 1 = ejecutada (filtro fundamental: cumpl_prog = 0) |
| Fecha programada original | `inicio_programado` | date | Fecha en que la OT debió ejecutarse |
| Fecha de reprogramación | `fecha_reprogramacion` | date | Nueva fecha asignada cuando la OT no se ejecutó |
| Peso del motivo principal | `peso_motivo` | numeric | Score 0..1 del motivo de no-ejecución |

---

## Dimensiones

### Dimensiones (entidades de negocio con hub propio)

| Dimensión | Campo | Hub asociado | Descripción |
|---|---|---|---|
| Máquina de control de polvo | `equipo_denom`, `ubicacion_tecnica` | `H_MAQUINA_CONTROL_POLVO` | Denominación y código de ubicación técnica |
| Planta | `planta_canon` | `H_PLANTA` | Planta donde está la máquina |
| Orden de trabajo | `orden_nro`, `ot_texto_breve` | `H_ORDEN_TRABAJO` | Número de OT y texto breve |
| Semana | `semana_nro` | `H_SEMANA` | Semana en que la OT fue programada |
| Tipo de equipo | `tipo_equipo` | `H_TIPO_EQUIPO_CTRL` | HDP / CDP / EPZ / VEX / VIN / PVA / PVM / PTV / PIN / DAM |
| Ámbito | `ambito` | `H_AMBITO` | mantencion (fijo) |

### Atributos del hecho (viven en satélites)

| Atributo | Campo | Satélite origen | Descripción |
|---|---|---|---|
| Familia de equipo | `familia` | `S_MAQCTRL_DESCR.familia` | renovacion_aire / abatidor_polvo |
| Motivo de no-ejecución | `motivo_no_ejecucion` | `S_OT_NO_EJECUCION.motivo_principal` | falta_repuestos (0.90) / no_entrega_operaciones (0.70) / falta_personal (0.60) |

### Atributos derivados de dimensión

| Atributo | Campo | Derivado de | Descripción |
|---|---|---|---|
| Año | `anio` | `S_SEMANA_DESCR.fecha_inicio` | Año calendario |

---

## Mapeo Hoja del Programa ↔ Planta canónica

| Hoja del Excel | `H_PLANTA.planta_canon` | Notas |
|---|---|---|
| `Chancado Fino` | Chancado Secundario y Terciario · Chancado Terciario y Cuaternario | Cabecera en fila 3. La denominación del equipo (col A) diferencia sub-planta |
| `Molienda` | Molienda SAG | Cabecera en fila 2 |
| `Chancado Primario` | Prechancado · Nodo 3500 | Cabecera en fila 2 |
| `Programa` (fallback) | CDM Linea 1 · CDM Linea 2 | Solo estas plantas se sirven desde la hoja maestra |

---

## Estructuras del Data Vault que dan origen al datamart

### Hubs

- `H_MAQUINA_CONTROL_POLVO` — dimensión máquina (la que no se mantuvo)
- `H_PLANTA` — dimensión planta
- `H_ORDEN_TRABAJO` — número y descripción de la OT
- `H_SEMANA` — dimensiones año y semana
- `H_TIPO_EQUIPO_CTRL` — tipo de equipo

### Links

- `L_OT_MAQCTRL` — asocia OT con máquina y semana programada
- `L_OT_RESPONSABLE` — asocia OT con persona responsable

### Satélites

- `S_MAQCTRL_DESCR` — denominación, tipo y familia de la máquina
- `S_PLANTA_DESCR` — planta_canon
- `S_OT_DESCR` — texto_breve, status_sistema
- `S_OT_PROGRAMACION` — inicio_programado (fecha original)
- `S_OT_EJECUCION` — cumpl_prog (filtro fundamental)
- `S_OT_NO_EJECUCION` — motivo_principal y fecha_reprogramacion
- `S_SEMANA_DESCR` — anio, semana_nro

### PIT y Bridge

- `PIT_OT` — pre-resuelve los sats de la OT en un solo lookup
- `BR_MANTENCION_SEMANAL` — **Bridge principal del datamart**. Denormaliza OT + máquina control polvo + planta + semana + responsable
- `BR_PLANTA_COBERTURA` — valida si el tipo de equipo consultado existe en la planta

---

## Correlación dato del datamart → tabla del Data Vault → origen físico

| Campo del datamart | Tabla origen en el DV | Archivo Excel | Hoja | Coordenada / Rango |
|---|---|---|---|---|
| `equipo_denom` | `S_MAQCTRL_DESCR.denominacion` (vía `BR_MANTENCION_SEMANAL`) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino (fila 3) · Molienda (fila 2) · Chancado Primario (fila 2) | Columna **A "Denominación"** |
| `ubicacion_tecnica` | `H_MAQUINA_CONTROL_POLVO.ubicacion_tecnica` (BK) | Programa_Semana_21_2026_Ventilacion.xlsx | Programa | Columna **G "Ubicación técnica"** (G2:G100) |
| `tipo_equipo` | `S_MAQCTRL_DESCR.tipo_equipo` (derivado) | Programa_Semana_21_2026_Ventilacion.xlsx | Programa | Derivado del 5° segmento del código en col G — HDP / CDP / EPZ / VEX / VIN / PVA / PVM / PTV / PIN / DAM |
| `familia` | `S_MAQCTRL_DESCR.familia` (derivado) | Programa_Semana_21_2026_Ventilacion.xlsx | Programa | Derivado del 4° segmento de col G: `SVE` → renovacion_aire, `SCP` → abatidor_polvo |
| `planta_canon` | `S_PLANTA_DESCR.nombre_canon` (vía `BR_MANTENCION_SEMANAL`) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Inferida por la hoja en que aparece la OT |
| `orden_nro` (Chancado Fino) | `H_ORDEN_TRABAJO.orden_nro` (BK) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino | Columna **B "Orden"** (B4:B348) |
| `orden_nro` (Molienda) | `H_ORDEN_TRABAJO.orden_nro` | Programa_Semana_21_2026_Ventilacion.xlsx | Molienda | Columna **B "Orden"** (B3:B196) |
| `orden_nro` (Chancado Primario) | `H_ORDEN_TRABAJO.orden_nro` | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Primario | Columna **B "Orden"** (B3:B57) |
| `orden_nro` (fallback CDM L1 y L2) | `H_ORDEN_TRABAJO.orden_nro` | Programa_Semana_21_2026_Ventilacion.xlsx | Programa | Columna **B "Orden"** (B2:B100) — solo CDM L1 y L2 |
| `ot_texto_breve` | `S_OT_DESCR.texto_breve` (vía `PIT_OT` y `BR_MANTENCION_SEMANAL`) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Columna **E "Txt.brv."** |
| `inicio_programado` | `S_OT_PROGRAMACION.inicio_programado` (vía `PIT_OT`) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Columna **H "FechaInicMásTmp"** |
| `cumpl_prog` | `S_OT_EJECUCION.cumpl_prog` | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Columna **O "CumplProg"** — filtro: cumpl_prog = 0 |
| `motivo_no_ejecucion` | `S_OT_NO_EJECUCION.motivo_principal` | — | — | **Sintético** asignado en ETL para OT con cumpl_prog = 0. Valores: `falta_repuestos` (0.90), `no_entrega_operaciones` (0.70), `falta_personal` (0.60). Caso ancla: OT 9856655 del V1 |
| `peso_motivo` | `S_OT_NO_EJECUCION.motivos` (json) | — | — | Calculado en ETL según el motivo principal asignado |
| `fecha_reprogramacion` | `S_OT_NO_EJECUCION.fecha_reprogramacion` | — | — | **Sintético** asignado en ETL. Por defecto `inicio_programado + 7 días` |
| `anio` | `BR_MANTENCION_SEMANAL` (derivado de `S_SEMANA_DESCR`) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Derivado: semana 21 de 2026 (declarada en celda B1) |
| `semana_nro` | `BR_MANTENCION_SEMANAL` (denormalizado desde `S_SEMANA_DESCR`) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino | Celda **B1** "Semana del Programa = 21" |
| `ambito` | `BR_MANTENCION_SEMANAL` (constante por diseño) | — | — | Valor fijo `mantencion` asignado durante el ETL |
