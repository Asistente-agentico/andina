# Datamart M_PROMEDIOS_PLANTA

**Ámbito**: fiscalización

## Preguntas que responde

### ¿Cuál fue el promedio de medición en la planta X?

```sql
SELECT
    planta_canon,
    ROUND(AVG(concentracion_mg_m3)::numeric, 3) AS promedio_mg_m3,
    COUNT(*)                                    AS n_mediciones
FROM M_PROMEDIOS_PLANTA
WHERE planta_canon = :planta
  AND estado = 'medido'
GROUP BY planta_canon;
```

### ¿Cuál fue el promedio considerando todas las plantas?

```sql
SELECT
    planta_canon,
    ROUND(AVG(concentracion_mg_m3)::numeric, 3) AS promedio_mg_m3,
    COUNT(*)                                    AS n_mediciones
FROM M_PROMEDIOS_PLANTA
WHERE estado = 'medido'
GROUP BY ROLLUP(planta_canon)
ORDER BY planta_canon NULLS LAST;
```

### ¿Cuál es la planta con los puntos de medición más altos?

```sql
SELECT
    planta_canon,
    ROUND(AVG(concentracion_mg_m3)::numeric, 3) AS promedio_mg_m3,
    ROUND(MAX(concentracion_mg_m3)::numeric, 3) AS pico_mg_m3
FROM M_PROMEDIOS_PLANTA
WHERE estado = 'medido'
GROUP BY planta_canon
ORDER BY promedio_mg_m3 DESC
LIMIT 1;
```

### ¿Cuál es la planta con los puntos de medición más bajos?

```sql
SELECT
    planta_canon,
    ROUND(AVG(concentracion_mg_m3)::numeric, 3) AS promedio_mg_m3,
    ROUND(MIN(concentracion_mg_m3)::numeric, 3) AS minimo_mg_m3
FROM M_PROMEDIOS_PLANTA
WHERE estado = 'medido' AND concentracion_mg_m3 > 0
GROUP BY planta_canon
ORDER BY promedio_mg_m3 ASC
LIMIT 1;
```

---

## Hechos

| Hecho | Campo | Tipo | Descripción |
|---|---|---|---|
| Concentración de polvo respirable | `concentracion_mg_m3` | numeric | Valor medido en miligramos por metro cúbico |
| Promedio de concentración | (calculado) | numeric | Promedio agregado por planta o global |
| Concentración máxima (pico) | (calculado) | numeric | Máximo agregado por planta |
| Concentración mínima | (calculado) | numeric | Mínimo agregado por planta |
| Conteo de mediciones | (calculado) | int | Número de mediciones válidas |

---

## Dimensiones

| Dimensión | Campo | Tipo | Descripción |
|---|---|---|---|
| Planta | `planta_canon` | varchar | Nombre canónico de la planta |
| Año | `anio` | int | Año calendario |
| Semana | `semana_nro` | int | Número de semana ISO |
| Fecha de medición | `fecha_medicion` | date | Fecha en que se tomó la medición |
| Estado de medición | `estado` | varchar | medido / no_medido (filtro: solo medido) |
| Ámbito | `ambito` | varchar | fiscalizacion (fijo en este datamart) |

---

## Estructuras del Data Vault que dan origen al datamart

### Hubs

| Hub | Rol |
|---|---|
| `H_PLANTA` | Provee la dimensión planta |
| `H_PUNTO_MEDICION` | Provee el detalle del punto cuando se necesita romper el promedio |
| `H_SEMANA` | Provee las dimensiones año y semana para filtros temporales |

### Links

| Link | Rol |
|---|---|
| `L_PUNTO_PLANTA` | Asocia cada punto con su planta |
| `L_MEDICION` | Registra la transacción de medición |

### Satélites

| Satélite | Rol |
|---|---|
| `S_PLANTA_DESCR` | Aporta `planta_canon` |
| `S_SEMANA_DESCR` | Aporta `anio`, `semana_nro`, `fecha_inicio`, `fecha_fin` |
| `S_MEDICION_VALOR` | Aporta el hecho `concentracion_mg_m3`, `fecha_medicion` y `estado` |

### PIT y Bridge

| Estructura | Rol |
|---|---|
| `PIT_MEDICION` | Pre-resuelve la versión vigente de `S_MEDICION_VALOR` por fecha de snapshot |
| `BR_MEDICION_SEMANAL` | Bridge principal. Aporta `planta_canon` y el contexto temporal denormalizados para que el promedio se calcule sin joins adicionales |

---

## Correlación dato del datamart → tabla del Data Vault → origen físico

| Campo del datamart | Tabla origen en el DV | Archivo Excel | Hoja | Coordenada / Rango |
|---|---|---|---|---|
| `concentracion_mg_m3` | `S_MEDICION_VALOR` (vía `PIT_MEDICION`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | C4:BV46 (matriz puntos × semanas, descartando columnas con sufijo FC) |
| `fecha_medicion` | `S_MEDICION_VALOR` | Puntos_Criticos_Semana_19_2026.xlsx | Prechancado / 2° y 3° / Cuaternario / Molienda Sag / CDM (1) / CDM (2) / Nodo | Fila "Fecha" de cada hoja de planta, intersectada con la columna de la semana correspondiente |
| `estado` | `S_MEDICION_VALOR` | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | Derivado: si C4:BV46 = 0 o vacío → `no_medido`; si > 0 → `medido` |
| `planta_canon` | `BR_MEDICION_SEMANAL` (denormalizado desde `S_PLANTA_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | B3, B9, B14, B21, B24, B29, B39 (filas separadoras de planta, normalizadas) |
| `anio` | `BR_MEDICION_SEMANAL` (denormalizado desde `S_SEMANA_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | C2:BV2 — derivado: semanas 1-52 = año 2025, semanas 1-19 de la segunda mitad = año 2026 |
| `semana_nro` | `BR_MEDICION_SEMANAL` (denormalizado desde `S_SEMANA_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | C2:BV2 — extraído del texto "Semana NN" |
| `ambito` | `BR_MEDICION_SEMANAL` (constante por diseño del bridge) | — | — | Valor fijo `fiscalizacion` asignado durante el ETL |
