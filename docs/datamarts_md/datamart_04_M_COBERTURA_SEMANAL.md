# Datamart M_COBERTURA_SEMANAL

**Ámbito**: fiscalización

## Preguntas que responde

### ¿Qué máquinas fueron medidas en la semana X?

```sql
SELECT DISTINCT
    planta_canon,
    maquina_gen_nombre,
    punto_nro,
    nombre_punto,
    concentracion_mg_m3,
    fecha_medicion
FROM M_COBERTURA_SEMANAL
WHERE anio = :anio
  AND semana_nro = :semana
  AND estado = 'medido'
ORDER BY planta_canon, maquina_gen_nombre;
```

---

## Hechos

| Hecho | Campo | Tipo | Descripción |
|---|---|---|---|
| Concentración de polvo respirable | `concentracion_mg_m3` | numeric | Valor medido en miligramos por metro cúbico de la máquina en esa semana |
| Conteo de máquinas medidas | (calculado) | int | Número de máquinas generadoras distintas medidas en la semana consultada |

---

## Dimensiones

### Dimensiones (entidades de negocio con hub propio)

| Dimensión | Campo | Hub asociado | Descripción |
|---|---|---|---|
| Planta | `planta_canon` | `H_PLANTA` | Nombre canónico de la planta |
| Máquina generadora | `maquina_gen_nombre` | `H_MAQUINA_GENERADORA` | Correa, harnero, chancador o alimentador |
| Punto de medición | `punto_nro`, `nombre_punto` | `H_PUNTO_MEDICION` | Código y nombre del punto crítico asociado a la máquina |
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
| Año | `anio` | `S_SEMANA_DESCR.fecha_inicio` | Año calendario extraído de la fecha de inicio de la semana |

---

## Estructuras del Data Vault que dan origen al datamart

### Hubs

| Hub | Rol |
|---|---|
| `H_PLANTA` | Provee la dimensión planta |
| `H_MAQUINA_GENERADORA` | Provee la dimensión máquina generadora |
| `H_PUNTO_MEDICION` | Provee el punto crítico asociado a cada máquina |
| `H_SEMANA` | Provee las dimensiones año y semana |

### Links

| Link | Rol |
|---|---|
| `L_PUNTO_PLANTA` | Asocia cada punto con su planta |
| `L_PUNTO_MAQGEN` | Asocia cada punto con su máquina generadora (1:1) |
| `L_MEDICION` | Registra la transacción de medición |

### Satélites

| Satélite | Rol |
|---|---|
| `S_PLANTA_DESCR` | Aporta `planta_canon` |
| `S_PUNTO_DESCR` | Aporta `nombre_display` del punto |
| `S_MAQGEN_DESCR` | Aporta el nombre y tipo de la máquina generadora |
| `S_SEMANA_DESCR` | Aporta `anio`, `semana_nro`, `fecha_inicio`, `fecha_fin` |
| `S_MEDICION_VALOR` | Aporta el hecho `concentracion_mg_m3`, `fecha_medicion` y `estado` |

### PIT y Bridge

| Estructura | Rol |
|---|---|
| `PIT_MEDICION` | Pre-resuelve la versión vigente de `S_MEDICION_VALOR` por fecha de snapshot |
| `BR_MEDICION_SEMANAL` | Bridge principal del datamart. Denormaliza medición + punto + planta + máquina generadora + semana en una sola fila |

---

## Correlación dato del datamart → tabla del Data Vault → origen físico

| Campo del datamart | Tabla origen en el DV | Archivo Excel | Hoja | Coordenada / Rango |
|---|---|---|---|---|
| `concentracion_mg_m3` | `S_MEDICION_VALOR` (vía `PIT_MEDICION`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | C4:BV46 (matriz puntos × semanas, descartando columnas con sufijo FC) |
| `fecha_medicion` | `S_MEDICION_VALOR` | Puntos_Criticos_Semana_19_2026.xlsx | Prechancado / 2° y 3° / Cuaternario / Molienda Sag / CDM (1) / CDM (2) / Nodo | Fila "Fecha" de cada hoja de planta, intersectada con la columna de la semana |
| `estado` | `S_MEDICION_VALOR` | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | Derivado: si C4:BV46 = 0 o vacío → `no_medido`; si > 0 → `medido` |
| `planta_canon` | `BR_MEDICION_SEMANAL` (denormalizado desde `S_PLANTA_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | B3, B9, B14, B21, B24, B29, B39 (filas separadoras de planta, normalizadas) |
| `maquina_gen_nombre` | `BR_MEDICION_SEMANAL` (denormalizado desde `S_MAQGEN_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | B4:B46 — texto antes del paréntesis (en este archivo, máquina generadora y nombre del punto coinciden) |
| `punto_nro` | `BR_MEDICION_SEMANAL` (denormalizado desde `H_PUNTO_MEDICION`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | B4:B46 — extraído del paréntesis `(N°)` del nombre; si no tiene paréntesis se asigna sintético 100-122 |
| `nombre_punto` | `BR_MEDICION_SEMANAL` (denormalizado desde `S_PUNTO_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | B4:B46 — texto antes del paréntesis |
| `anio` | `BR_MEDICION_SEMANAL` (derivado de `S_SEMANA_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | C2:BV2 — derivado: semanas 1-52 = año 2025, semanas 1-19 de la segunda mitad = año 2026 |
| `semana_nro` | `BR_MEDICION_SEMANAL` (denormalizado desde `S_SEMANA_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | C2:BV2 — extraído del texto "Semana NN" |
| `ambito` | `BR_MEDICION_SEMANAL` (constante por diseño del bridge) | — | — | Valor fijo `fiscalizacion` asignado durante el ETL |
