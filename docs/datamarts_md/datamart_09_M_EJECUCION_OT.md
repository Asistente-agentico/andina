# Datamart M_EJECUCION_OT

**Ámbito**: mantención

## Preguntas que responde

### Para el sistema X, ¿cuándo se realizó la última mantención?

```sql
SELECT
    equipo_denom,
    orden_nro,
    ot_texto_breve,
    inicio_programado,
    anio,
    semana_nro,
    hh_reales,
    responsable_nombre
FROM M_EJECUCION_OT
WHERE equipo_denom ILIKE :maquina
  AND cumpl_prog = 1
ORDER BY anio DESC, semana_nro DESC
LIMIT 1;
```

### ¿Quién realizó la mantención de la máquina X?

```sql
SELECT
    equipo_denom,
    orden_nro,
    anio,
    semana_nro,
    responsable_nombre
FROM M_EJECUCION_OT
WHERE equipo_denom ILIKE :maquina
  AND cumpl_prog = 1
ORDER BY anio DESC, semana_nro DESC;
```

### ¿Cuántas personas trabajaron en la mantención?

```sql
SELECT
    orden_nro,
    equipo_denom,
    anio,
    semana_nro,
    personal_real AS personas_que_trabajaron,
    personal_prog AS personas_planificadas
FROM M_EJECUCION_OT
WHERE orden_nro = :orden_nro
   OR equipo_denom ILIKE :maquina;
```

### ¿En qué fecha se realizó la última mantención a la máquina / sistema?

```sql
SELECT
    equipo_denom,
    orden_nro,
    inicio_programado AS fecha_planificada,
    anio,
    semana_nro
FROM M_EJECUCION_OT
WHERE equipo_denom ILIKE :maquina
  AND cumpl_prog = 1
ORDER BY anio DESC, semana_nro DESC
LIMIT 1;
```

### ¿Cuánto tiempo se planificó para la mantención y cuánto tiempo realmente tomó?

```sql
SELECT
    orden_nro,
    equipo_denom,
    ot_texto_breve,
    anio,
    semana_nro,
    hh_planificadas,
    hh_reales,
    duracion_planificada,
    duracion_real,
    (hh_reales - hh_planificadas) AS desviacion_hh
FROM M_EJECUCION_OT
WHERE orden_nro = :orden_nro
   OR equipo_denom ILIKE :maquina
ORDER BY anio DESC, semana_nro DESC;
```

---

## Hechos

| Hecho | Campo | Tipo | Descripción |
|---|---|---|---|
| Indicador de cumplimiento | `cumpl_prog` | int | 1 = ejecutada (filtro fundamental: cumpl_prog = 1) |
| Horas-hombre planificadas | `hh_planificadas` | numeric | Horas-hombre programadas para la OT |
| Horas-hombre reales | `hh_reales` | numeric | Horas-hombre efectivamente trabajadas |
| Personal planificado | `personal_prog` | int | Cantidad de personas planificadas |
| Personal real | `personal_real` | int | Cantidad de personas que realmente trabajaron |
| Duración planificada | `duracion_planificada` | numeric | Duración en horas planificada |
| Duración real | `duracion_real` | numeric | Duración en horas real |
| Adherencia al programa | `adherencia_prog` | numeric | Score de adherencia al programa |

---

## Dimensiones

### Dimensiones (entidades de negocio con hub propio)

| Dimensión | Campo | Hub asociado | Descripción |
|---|---|---|---|
| Máquina de control de polvo | `equipo_denom`, `ubicacion_tecnica` | `H_MAQUINA_CONTROL_POLVO` | Denominación y código de ubicación técnica |
| Planta | `planta_canon` | `H_PLANTA` | Planta donde está la máquina |
| Orden de trabajo | `orden_nro`, `ot_texto_breve` | `H_ORDEN_TRABAJO` | Número de OT y texto breve |
| Semana | `semana_nro` | `H_SEMANA` | Semana en que la OT fue ejecutada |
| Responsable | `responsable_nombre` | `H_PERSONA` | Persona que ejecutó la mantención |
| Tipo de equipo | `tipo_equipo` | `H_TIPO_EQUIPO_CTRL` | HDP / CDP / EPZ / VEX / VIN... |
| Ámbito | `ambito` | `H_AMBITO` | mantencion (fijo) |

### Atributos del hecho (viven en satélites)

| Atributo | Campo | Satélite origen | Descripción |
|---|---|---|---|
| Familia de equipo | `familia` | `S_MAQCTRL_DESCR.familia` | renovacion_aire / abatidor_polvo |
| Status del sistema | `status_sistema` | `S_OT_DESCR.status_sistema` | Estado SAP de la OT |
| Fecha programada | `inicio_programado` | `S_OT_PROGRAMACION.inicio_programado` | Fecha planificada de inicio |
| Día efectivo de ejecución | `dia_ejecutado` | `S_OT_EJECUCION.dia_ejecutado` | Día específico en que se realizó (Lunes a Domingo) |

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

- `H_MAQUINA_CONTROL_POLVO` — máquina que fue mantenida
- `H_PLANTA` — planta
- `H_ORDEN_TRABAJO` — OT ejecutada
- `H_SEMANA` — semana de ejecución
- `H_PERSONA` — responsable de la mantención
- `H_TIPO_EQUIPO_CTRL` — tipo de equipo

### Links

- `L_OT_MAQCTRL` — asocia OT con máquina y semana
- `L_OT_RESPONSABLE` — asocia OT con responsable

### Satélites

- `S_MAQCTRL_DESCR` — denominación, tipo y familia
- `S_PLANTA_DESCR` — planta_canon
- `S_OT_DESCR` — texto_breve, status_sistema
- `S_OT_PROGRAMACION` — inicio_programado, fecha_liberacion
- `S_OT_EJECUCION` — cumpl_prog, hh_planificadas, hh_reales, personal_prog, personal_real, duracion_planificada, duracion_real, adherencia_prog, dia_ejecutado
- `S_PERSONA_DESCR` — nombre del responsable

### PIT y Bridge

- `PIT_OT` — pre-resuelve los sats de la OT en un solo lookup
- `BR_MANTENCION_SEMANAL` — **Bridge principal del datamart**. Denormaliza OT + máquina + planta + semana + responsable

---

## Correlación dato del datamart → tabla del Data Vault → origen físico

| Campo del datamart | Tabla origen en el DV | Archivo Excel | Hoja | Coordenada / Rango |
|---|---|---|---|---|
| `equipo_denom` | `S_MAQCTRL_DESCR.denominacion` (vía `BR_MANTENCION_SEMANAL`) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino (fila 3) · Molienda (fila 2) · Chancado Primario (fila 2) | Columna **A "Denominación"** |
| `ubicacion_tecnica` | `H_MAQUINA_CONTROL_POLVO.ubicacion_tecnica` (BK) | Programa_Semana_21_2026_Ventilacion.xlsx | Programa | Columna **G "Ubicación técnica"** |
| `tipo_equipo` | `S_MAQCTRL_DESCR.tipo_equipo` (derivado) | Programa_Semana_21_2026_Ventilacion.xlsx | Programa | Derivado del 5° segmento de col G |
| `familia` | `S_MAQCTRL_DESCR.familia` (derivado) | Programa_Semana_21_2026_Ventilacion.xlsx | Programa | Derivado del 4° segmento de col G |
| `planta_canon` | `S_PLANTA_DESCR.nombre_canon` (vía `BR_MANTENCION_SEMANAL`) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Inferida por la hoja en que aparece la OT |
| `orden_nro` (Chancado Fino) | `H_ORDEN_TRABAJO.orden_nro` (BK) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino | Columna **B "Orden"** (B4:B348) |
| `orden_nro` (Molienda) | `H_ORDEN_TRABAJO.orden_nro` | Programa_Semana_21_2026_Ventilacion.xlsx | Molienda | Columna **B "Orden"** (B3:B196) |
| `orden_nro` (Chancado Primario) | `H_ORDEN_TRABAJO.orden_nro` | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Primario | Columna **B "Orden"** (B3:B57) |
| `ot_texto_breve` | `S_OT_DESCR.texto_breve` (vía `PIT_OT`) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Columna **E "Txt.brv."** |
| `status_sistema` | `S_OT_DESCR.status_sistema` | Programa_Semana_21_2026_Ventilacion.xlsx | Programa | Columna **I "Status de sistema"** |
| `inicio_programado` | `S_OT_PROGRAMACION.inicio_programado` (vía `PIT_OT`) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Columna **H "FechaInicMásTmp"** |
| `cumpl_prog` | `S_OT_EJECUCION.cumpl_prog` | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Columna **O "CumplProg"** — filtro: cumpl_prog = 1 |
| `hh_planificadas` (Molienda, Chancado Primario) | `S_OT_EJECUCION.hh_planificadas` | Programa_Semana_21_2026_Ventilacion.xlsx | Molienda · Chancado Primario | Columna **I "HorasHombreProg."** |
| `hh_planificadas` (Chancado Fino) | `S_OT_EJECUCION.hh_planificadas` | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino | Columna **I "Trabajo"** (la hoja Chancado Fino usa nombre distinto) |
| `hh_reales` | `S_OT_EJECUCION.hh_reales` | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Columna **L "HorasHombreReal"** |
| `duracion_planificada` (Molienda, Chancado Primario) | `S_OT_EJECUCION.duracion_planificada` | Programa_Semana_21_2026_Ventilacion.xlsx | Molienda · Chancado Primario | Columna **J "DuraciónProg."** |
| `duracion_planificada` (Chancado Fino) | `S_OT_EJECUCION.duracion_planificada` | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino | Columna **J "Duración normal"** |
| `duracion_real` | `S_OT_EJECUCION.duracion_real` | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Columna **M "DuraciónReal"** |
| `personal_prog` | `S_OT_EJECUCION.personal_prog` | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Columna **K "PersonalProg"** |
| `personal_real` | `S_OT_EJECUCION.personal_real` | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Columna **N "PersonalReal"** |
| `adherencia_prog` | `S_OT_EJECUCION.adherencia_prog` | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Columna **P "AdherenciaProg"** |
| `dia_ejecutado` | `S_OT_EJECUCION.dia_ejecutado` (derivado en ETL) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Columnas **Q a W** (Lunes a Domingo) — se identifica la columna con valor distinto de 0 y se traduce a fecha real |
| `responsable_nombre` | `S_PERSONA_DESCR.nombre_completo` (vía `L_OT_RESPONSABLE`) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Columna **G "Responsable"** — normalizado en ETL |
| `anio` | `BR_MANTENCION_SEMANAL` (derivado de `S_SEMANA_DESCR`) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Derivado: semana 21 de 2026 (celda B1) |
| `semana_nro` | `BR_MANTENCION_SEMANAL` (denormalizado desde `S_SEMANA_DESCR`) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino | Celda **B1** "Semana del Programa = 21" |
| `ambito` | `BR_MANTENCION_SEMANAL` (constante por diseño) | — | — | Valor fijo `mantencion` asignado durante el ETL |
