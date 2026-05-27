# Datamart M_VENTANAS_TEMPORALES

**Ámbito**: fiscalización

## Preguntas que responde

### ¿Entre qué semanas ocurre el mayor número de puntos con alto grado de polución en la planta X?

```sql
WITH eventos_altos AS (
    SELECT anio, semana_nro
    FROM M_VENTANAS_TEMPORALES
    WHERE planta_canon = :planta
      AND concentracion_mg_m3 >= 2.5
),
por_semana AS (
    SELECT anio, semana_nro, COUNT(*) AS n_altos
    FROM eventos_altos
    GROUP BY anio, semana_nro
)
SELECT anio,
       semana_nro AS semana_inicio,
       semana_nro + 3 AS semana_fin,
       SUM(n_altos) OVER (PARTITION BY anio ORDER BY semana_nro
                          ROWS BETWEEN CURRENT ROW AND 3 FOLLOWING) AS n_altos_ventana
FROM por_semana
ORDER BY n_altos_ventana DESC NULLS LAST
LIMIT 1;
```

### ¿Entre qué semanas ocurre el mayor número de altas concentraciones en el punto X?

```sql
SELECT anio,
       MIN(semana_nro) AS desde,
       MAX(semana_nro) AS hasta,
       COUNT(*)        AS n_eventos
FROM M_VENTANAS_TEMPORALES
WHERE punto_nro = :punto_nro
  AND concentracion_mg_m3 >= 2.5
GROUP BY anio;
```

### ¿Entre qué semanas ocurre el mayor número de bajas concentraciones en el punto X?

```sql
SELECT anio,
       MIN(semana_nro) AS desde,
       MAX(semana_nro) AS hasta,
       COUNT(*)        AS n_eventos
FROM M_VENTANAS_TEMPORALES
WHERE punto_nro = :punto_nro
  AND estado = 'medido'
  AND concentracion_mg_m3 BETWEEN 0.01 AND 1.0
GROUP BY anio;
```

### ¿Entre qué semanas ocurre el mayor número de puntos con bajo grado de polución en la planta X?

```sql
WITH eventos_bajos AS (
    SELECT anio, semana_nro
    FROM M_VENTANAS_TEMPORALES
    WHERE planta_canon = :planta
      AND estado = 'medido'
      AND concentracion_mg_m3 BETWEEN 0.01 AND 1.0
),
por_semana AS (
    SELECT anio, semana_nro, COUNT(*) AS n_bajos
    FROM eventos_bajos
    GROUP BY anio, semana_nro
)
SELECT anio,
       semana_nro AS semana_inicio,
       semana_nro + 3 AS semana_fin,
       SUM(n_bajos) OVER (PARTITION BY anio ORDER BY semana_nro
                          ROWS BETWEEN CURRENT ROW AND 3 FOLLOWING) AS n_bajos_ventana
FROM por_semana
ORDER BY n_bajos_ventana DESC NULLS LAST
LIMIT 1;
```

---

## Hechos

| Hecho | Campo | Tipo | Descripción |
|---|---|---|---|
| Concentración de polvo respirable | `concentracion_mg_m3` | numeric | Valor medido en miligramos por metro cúbico |
| Conteo de eventos sobre umbral alto | (calculado) | int | Número de mediciones ≥ 2.5 mg/m³ en la ventana |
| Conteo de eventos bajo umbral | (calculado) | int | Número de mediciones entre 0.01 y 1.0 mg/m³ en la ventana |
| Ventana móvil (4 semanas) | (calculado) | int | Suma deslizante de eventos sobre 4 semanas consecutivas |

---

## Dimensiones

### Dimensiones (entidades de negocio con hub propio)

| Dimensión | Campo | Hub asociado | Descripción |
|---|---|---|---|
| Planta | `planta_canon` | `H_PLANTA` | Nombre canónico de la planta |
| Punto de medición | `punto_nro`, `nombre_punto` | `H_PUNTO_MEDICION` | Código y nombre del punto crítico |
| Semana | `semana_nro` | `H_SEMANA` | Número de semana ISO |
| Ámbito | `ambito` | `H_AMBITO` | fiscalizacion (fijo en este datamart) |

### Atributos del hecho (viven en el satélite del link transaccional)

| Atributo | Campo | Satélite origen | Descripción |
|---|---|---|---|
| Fecha de medición | `fecha_medicion` | `S_MEDICION_VALOR` | Fecha en que se tomó la medición |
| Estado de medición | `estado` | `S_MEDICION_VALOR` | medido / no_medido (filtro: solo medido) |

### Atributos derivados de dimensión (calculados en el ETL del bridge)

| Atributo | Campo | Derivado de | Descripción |
|---|---|---|---|
| Año | `anio` | `S_SEMANA_DESCR.fecha_inicio` | Año calendario |
| Semana inicio de ventana | `semana_inicio` | `semana_nro` | Primera semana de la ventana móvil (4 sem) |
| Semana fin de ventana | `semana_fin` | `semana_nro + 3` | Última semana de la ventana móvil |

---

## Estructuras del Data Vault que dan origen al datamart

### Hubs

| Hub | Rol |
|---|---|
| `H_PLANTA` | Provee la dimensión planta |
| `H_PUNTO_MEDICION` | Provee la dimensión punto |
| `H_SEMANA` | Provee las dimensiones año y semana |

### Links

| Link | Rol |
|---|---|
| `L_PUNTO_PLANTA` | Asocia cada punto con su planta |
| `L_MEDICION` | Registra la transacción de medición |

### Satélites

| Satélite | Rol |
|---|---|
| `S_PLANTA_DESCR` | Aporta `planta_canon` |
| `S_PUNTO_DESCR` | Aporta `nombre_display` del punto |
| `S_SEMANA_DESCR` | Aporta `anio`, `semana_nro`, `fecha_inicio`, `fecha_fin` |
| `S_MEDICION_VALOR` | Aporta el hecho `concentracion_mg_m3`, `fecha_medicion` y `estado` |

### PIT y Bridge

| Estructura | Rol |
|---|---|
| `PIT_MEDICION` | Pre-resuelve la versión vigente de `S_MEDICION_VALOR` por fecha de snapshot |
| `BR_MEDICION_SEMANAL` | Bridge principal del datamart. Denormaliza medición + punto + planta + semana en una sola fila |

---

## Correlación dato del datamart → tabla del Data Vault → origen físico

| Campo del datamart | Tabla origen en el DV | Archivo Excel | Hoja | Coordenada / Rango |
|---|---|---|---|---|
| `concentracion_mg_m3` | `S_MEDICION_VALOR` (vía `PIT_MEDICION`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | C4:BV46 (matriz puntos × semanas, descartando columnas con sufijo FC) |
| `fecha_medicion` | `S_MEDICION_VALOR` | Puntos_Criticos_Semana_19_2026.xlsx | Prechancado / 2° y 3° / Cuaternario / Molienda Sag / CDM (1) / CDM (2) / Nodo | Fila "Fecha" de cada hoja de planta, intersectada con la columna de la semana |
| `estado` | `S_MEDICION_VALOR` | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | Derivado: si C4:BV46 = 0 o vacío → `no_medido`; si > 0 → `medido` |
| `planta_canon` | `BR_MEDICION_SEMANAL` (denormalizado desde `S_PLANTA_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | B3, B9, B14, B21, B24, B29, B39 (filas separadoras de planta, normalizadas) |
| `punto_nro` | `BR_MEDICION_SEMANAL` (denormalizado desde `H_PUNTO_MEDICION`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | B4:B46 — extraído del paréntesis `(N°)` del nombre; si no tiene paréntesis se asigna sintético 100-122 |
| `nombre_punto` | `BR_MEDICION_SEMANAL` (denormalizado desde `S_PUNTO_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | B4:B46 — texto antes del paréntesis |
| `anio` | `BR_MEDICION_SEMANAL` (derivado de `S_SEMANA_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | C2:BV2 — derivado: semanas 1-52 = año 2025, semanas 1-19 de la segunda mitad = año 2026 |
| `semana_nro` | `BR_MEDICION_SEMANAL` (denormalizado desde `S_SEMANA_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | C2:BV2 — extraído del texto "Semana NN" |
| `ambito` | `BR_MEDICION_SEMANAL` (constante por diseño del bridge) | — | — | Valor fijo `fiscalizacion` asignado durante el ETL |
