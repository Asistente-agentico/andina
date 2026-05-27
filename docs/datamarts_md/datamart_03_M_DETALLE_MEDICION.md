# Datamart M_DETALLE_MEDICION

**Ámbito**: fiscalización

## Preguntas que responde

### ¿En qué fecha y horario se tomó la medición en el punto X de la planta Y?

```sql
SELECT
    planta_canon,
    punto_nro,
    nombre_punto,
    anio,
    semana_nro,
    fecha_medicion,
    hora_inicio,
    hora_termino,
    concentracion_mg_m3,
    estado
FROM M_DETALLE_MEDICION
WHERE punto_nro = :punto_nro
  AND planta_canon = :planta
ORDER BY anio, semana_nro;
```

### ¿Quién fue el responsable de tomar la medición?

```sql
SELECT
    planta_canon,
    punto_nro,
    nombre_punto,
    anio,
    semana_nro,
    fecha_medicion,
    operador_panel,
    tecnico_higiene
FROM M_DETALLE_MEDICION
WHERE punto_nro = :punto_nro
  AND (:planta IS NULL OR planta_canon = :planta)
ORDER BY anio, semana_nro;
```

### ¿Por qué no se tomó la medición en la fecha X?

```sql
SELECT
    planta_canon,
    punto_nro,
    nombre_punto,
    anio,
    semana_nro,
    fecha_inicio_semana,
    estado,
    motivo_no_medicion
FROM M_DETALLE_MEDICION
WHERE estado = 'no_medido'
  AND (:fecha IS NULL OR fecha_inicio_semana <= :fecha::date)
ORDER BY planta_canon, punto_nro, anio, semana_nro;
```

---

## Hechos

| Hecho | Campo | Tipo | Descripción |
|---|---|---|---|
| Concentración de polvo respirable | `concentracion_mg_m3` | numeric | Valor medido en miligramos por metro cúbico |
| Hora de inicio | `hora_inicio` | time | Hora en que comenzó la medición |
| Hora de término | `hora_termino` | time | Hora en que terminó la medición |

---

## Dimensiones

### Dimensiones (entidades de negocio con hub propio)

| Dimensión | Campo | Hub asociado | Descripción |
|---|---|---|---|
| Planta | `planta_canon` | `H_PLANTA` | Nombre canónico de la planta |
| Punto de medición | `punto_nro`, `nombre_punto` | `H_PUNTO_MEDICION` | Código y nombre del punto crítico |
| Semana | `semana_nro` | `H_SEMANA` | Número de semana ISO |
| Operador de panel | `operador_panel` | `H_PERSONA` | Persona en panel durante la medición |
| Técnico en higiene | `tecnico_higiene` | `H_PERSONA` | Persona que realizó la medición |
| Ámbito | `ambito` | `H_AMBITO` | fiscalizacion (fijo en este datamart) |

### Atributos del hecho (viven en el satélite del link transaccional)

| Atributo | Campo | Satélite origen | Descripción |
|---|---|---|---|
| Fecha de medición | `fecha_medicion` | `S_MEDICION_VALOR` | Fecha en que se tomó la medición |
| Estado de medición | `estado` | `S_MEDICION_VALOR` | medido / no_medido |
| Motivo de no-medición | `motivo_no_medicion` | `S_MEDICION_VALOR` | feriado / falla_equipo_medicion / ausencia_tecnico / acceso_restringido (solo cuando estado = no_medido) |

### Atributos derivados de dimensión (calculados en el ETL del bridge)

| Atributo | Campo | Derivado de | Descripción |
|---|---|---|---|
| Año | `anio` | `S_SEMANA_DESCR.fecha_inicio` | Año calendario extraído de la fecha de inicio de la semana |
| Fecha de inicio de semana | `fecha_inicio_semana` | `S_SEMANA_DESCR.fecha_inicio` | Primer día de la semana ISO |

---

## Estructuras del Data Vault que dan origen al datamart

### Hubs

| Hub | Rol |
|---|---|
| `H_PLANTA` | Provee la dimensión planta |
| `H_PUNTO_MEDICION` | Provee la dimensión punto |
| `H_SEMANA` | Provee las dimensiones semana y año |
| `H_PERSONA` | Provee operador y técnico |

### Links

| Link | Rol |
|---|---|
| `L_PUNTO_PLANTA` | Asocia cada punto con su planta |
| `L_MEDICION` | Registra la transacción de medición (punto × semana × operador × técnico) |

### Satélites

| Satélite | Rol |
|---|---|
| `S_PLANTA_DESCR` | Aporta `planta_canon` |
| `S_PUNTO_DESCR` | Aporta `nombre_display` del punto |
| `S_SEMANA_DESCR` | Aporta `anio`, `semana_nro`, `fecha_inicio`, `fecha_fin` |
| `S_PERSONA_DESCR` | Aporta nombre completo del operador y técnico (con normalización ortográfica) |
| `S_MEDICION_VALOR` | Aporta los hechos `concentracion_mg_m3`, `hora_inicio`, `hora_termino`, y los atributos `fecha_medicion`, `estado`, `motivo_no_medicion` |

### PIT y Bridge

| Estructura | Rol |
|---|---|
| `PIT_MEDICION` | Pre-resuelve la versión vigente de `S_MEDICION_VALOR` por fecha de snapshot |
| `BR_MEDICION_SEMANAL` | Bridge principal del datamart. Denormaliza medición + punto + planta + semana + operador + técnico en una sola fila |

---

## Correlación dato del datamart → tabla del Data Vault → origen físico

| Campo del datamart | Tabla origen en el DV | Archivo Excel | Hoja | Coordenada / Rango |
|---|---|---|---|---|
| `concentracion_mg_m3` | `S_MEDICION_VALOR` (vía `PIT_MEDICION`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | C4:BV46 (matriz puntos × semanas, descartando columnas con sufijo FC) |
| `hora_inicio` | `S_MEDICION_VALOR` | Puntos_Criticos_Semana_19_2026.xlsx | Prechancado / 2° y 3° / Cuaternario / Molienda Sag / CDM (1) / CDM (2) / Nodo | Fila "Hora inicio" de cada hoja de planta, intersectada con la columna de la semana |
| `hora_termino` | `S_MEDICION_VALOR` | Puntos_Criticos_Semana_19_2026.xlsx | Prechancado / 2° y 3° / Cuaternario / Molienda Sag / CDM (1) / CDM (2) / Nodo | Fila "Hora termino" de cada hoja de planta, intersectada con la columna de la semana |
| `fecha_medicion` | `S_MEDICION_VALOR` | Puntos_Criticos_Semana_19_2026.xlsx | Prechancado / 2° y 3° / Cuaternario / Molienda Sag / CDM (1) / CDM (2) / Nodo | Fila "Fecha" de cada hoja de planta, intersectada con la columna de la semana |
| `estado` | `S_MEDICION_VALOR` | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | Derivado: si C4:BV46 = 0 o vacío → `no_medido`; si > 0 → `medido` |
| `motivo_no_medicion` | `S_MEDICION_VALOR` | — | — | **Sintético** asignado en ETL para celdas con `estado = no_medido`. Valores: `feriado`, `falla_equipo_medicion`, `ausencia_tecnico`, `acceso_restringido` |
| `planta_canon` | `BR_MEDICION_SEMANAL` (denormalizado desde `S_PLANTA_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | B3, B9, B14, B21, B24, B29, B39 (filas separadoras de planta, normalizadas) |
| `punto_nro` | `BR_MEDICION_SEMANAL` (denormalizado desde `H_PUNTO_MEDICION`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | B4:B46 — extraído del paréntesis `(N°)` del nombre; si no tiene paréntesis se asigna sintético 100-122 |
| `nombre_punto` | `BR_MEDICION_SEMANAL` (denormalizado desde `S_PUNTO_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | B4:B46 — texto antes del paréntesis |
| `operador_panel` | `BR_MEDICION_SEMANAL` (denormalizado desde `S_PERSONA_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Hojas de planta (Prechancado, 2° y 3°, etc.) | Fila "Operador" de cada hoja de planta, intersectada con la columna de la semana — normalizado (variantes ortográficas consolidadas) |
| `tecnico_higiene` | `BR_MEDICION_SEMANAL` (denormalizado desde `S_PERSONA_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Hojas de planta | Fila "Tecnico" (o "Técnico") de cada hoja de planta, intersectada con la columna de la semana — normalizado |
| `anio` | `BR_MEDICION_SEMANAL` (derivado de `S_SEMANA_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | C2:BV2 — derivado: semanas 1-52 = año 2025, semanas 1-19 de la segunda mitad = año 2026 |
| `semana_nro` | `BR_MEDICION_SEMANAL` (denormalizado desde `S_SEMANA_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | C2:BV2 — extraído del texto "Semana NN" |
| `fecha_inicio_semana` | `BR_MEDICION_SEMANAL` (derivado en ETL) | — | — | Calculado: primer día de la semana ISO a partir de `anio + semana_nro` |
| `ambito` | `BR_MEDICION_SEMANAL` (constante por diseño del bridge) | — | — | Valor fijo `fiscalizacion` asignado durante el ETL |
