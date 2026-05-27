# Datamart M_TENDENCIAS

**Ámbito**: fiscalización

## Preguntas que responde

### ¿Cuál de todas las plantas tiene la tendencia de crecer en polución alto y cuáles son esos puntos de medición?

```sql
WITH prom_planta_semana AS (
    SELECT planta_canon, semana_nro, AVG(concentracion_mg_m3) AS prom
    FROM M_TENDENCIAS
    WHERE estado = 'medido'
    GROUP BY planta_canon, semana_nro
),
tendencia AS (
    SELECT planta_canon,
           REGR_SLOPE(prom, semana_nro) AS pendiente,
           REGR_R2(prom, semana_nro)    AS r2
    FROM prom_planta_semana
    GROUP BY planta_canon
),
top_planta AS (
    SELECT planta_canon, pendiente, r2 FROM tendencia
    WHERE pendiente > 0
    ORDER BY pendiente DESC
    LIMIT 1
)
SELECT tp.planta_canon,
       tp.pendiente,
       tp.r2,
       m.punto_nro,
       m.nombre_punto,
       ROUND(AVG(m.concentracion_mg_m3)::numeric, 3) AS promedio_punto
FROM top_planta tp
JOIN M_TENDENCIAS m ON m.planta_canon = tp.planta_canon
WHERE m.estado = 'medido'
GROUP BY tp.planta_canon, tp.pendiente, tp.r2, m.punto_nro, m.nombre_punto
ORDER BY promedio_punto DESC;
```

---

## Hechos

| Hecho | Campo | Tipo | Descripción |
|---|---|---|---|
| Concentración de polvo respirable | `concentracion_mg_m3` | numeric | Valor medido en miligramos por metro cúbico |
| Pendiente de regresión lineal | (calculado) | numeric | mg/m³ por semana — pendiente de la regresión sobre el promedio semanal por planta |
| Coeficiente de determinación R² | (calculado) | numeric | Bondad de ajuste de la regresión lineal |
| Promedio por punto | (calculado) | numeric | Promedio histórico de concentración por punto |

---

## Dimensiones

### Dimensiones (entidades de negocio con hub propio)

| Dimensión | Campo | Hub asociado | Descripción |
|---|---|---|---|
| Planta | `planta_canon` | `H_PLANTA` | Nombre canónico de la planta |
| Punto de medición | `punto_nro`, `nombre_punto` | `H_PUNTO_MEDICION` | Código y nombre del punto crítico |
| Semana | `semana_nro` | `H_SEMANA` | Número de semana ISO (eje X de la regresión) |
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

---

## Estructuras del Data Vault que dan origen al datamart

### Hubs

| Hub | Rol |
|---|---|
| `H_PLANTA` | Provee la dimensión planta |
| `H_PUNTO_MEDICION` | Provee la dimensión punto |
| `H_SEMANA` | Provee las dimensiones año y semana (eje temporal de la regresión) |

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
| `BR_MEDICION_SEMANAL` | Bridge principal del datamart. Denormaliza medición + punto + planta + semana en una sola fila para que la regresión `REGR_SLOPE` opere sin joins adicionales |

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
