# Datamart M_RANKING_SEMANAL

**Ámbito**: fiscalización

## Preguntas que responde

- ¿Dónde está el punto de medición más alto esta semana?
- ¿Dónde está el punto de medición más bajo esta semana?

---

## Hechos

| Hecho | Campo | Tipo | Descripción |
|---|---|---|---|
| Concentración de polvo respirable | `concentracion_mg_m3` | numeric | Valor medido en miligramos por metro cúbico |

---

## Dimensiones

| Dimensión | Campo | Tipo | Descripción |
|---|---|---|---|
| Planta | `planta_canon` | varchar | Nombre canónico de la planta |
| Punto de medición | `punto_nro` | int | Código del punto crítico |
| Punto de medición | `nombre_punto` | varchar | Nombre descriptivo del punto |
| Máquina generadora | `maquina_gen_nombre` | varchar | Correa, harnero, chancador o alimentador asociado |
| Año | `anio` | int | Año calendario |
| Semana | `semana_nro` | int | Número de semana ISO |
| Fecha de medición | `fecha_medicion` | date | Fecha en que se tomó la medición |
| Estado de medición | `estado` | varchar | medido / no_medido |
| Ámbito | `ambito` | varchar | fiscalizacion (fijo en este datamart) |

---

## Estructuras del Data Vault que dan origen al datamart

### Hubs

| Hub | Rol |
|---|---|
| `H_PLANTA` | Provee la dimensión planta |
| `H_PUNTO_MEDICION` | Provee la dimensión punto |
| `H_MAQUINA_GENERADORA` | Provee la dimensión máquina generadora |
| `H_SEMANA` | Provee las dimensiones año y semana |

### Links

| Link | Rol |
|---|---|
| `L_PUNTO_PLANTA` | Asocia cada punto con su planta |
| `L_PUNTO_MAQGEN` | Asocia cada punto con su máquina generadora |
| `L_MEDICION` | Registra la transacción de medición (punto × semana × operador × técnico) |

### Satélites

| Satélite | Rol |
|---|---|
| `S_PLANTA_DESCR` | Aporta `planta_canon` |
| `S_PUNTO_DESCR` | Aporta `nombre_display` del punto |
| `S_MAQGEN_DESCR` | Aporta el nombre de la máquina generadora |
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
| `fecha_medicion` | `S_MEDICION_VALOR` | Puntos_Criticos_Semana_19_2026.xlsx | Prechancado / 2° y 3° / Cuaternario / Molienda Sag / CDM (1) / CDM (2) / Nodo | Fila "Fecha" de cada hoja de planta, intersectada con la columna de la semana correspondiente |
| `estado` | `S_MEDICION_VALOR` | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | Derivado: si C4:BV46 = 0 o vacío → `no_medido`; si > 0 → `medido` |
| `planta_canon` | `BR_MEDICION_SEMANAL` (denormalizado desde `S_PLANTA_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | B3, B9, B14, B21, B24, B29, B39 (filas separadoras de planta, normalizadas) |
| `punto_nro` | `BR_MEDICION_SEMANAL` (denormalizado desde `H_PUNTO_MEDICION`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | B4:B46 — extraído del paréntesis `(N°)` del nombre; si no tiene paréntesis se asigna sintético 100-122 |
| `nombre_punto` | `BR_MEDICION_SEMANAL` (denormalizado desde `S_PUNTO_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | B4:B46 — texto antes del paréntesis |
| `maquina_gen_nombre` | `BR_MEDICION_SEMANAL` (denormalizado desde `S_MAQGEN_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | B4:B46 — mismo texto antes del paréntesis (la máquina generadora coincide con el nombre del punto en este archivo) |
| `anio` | `BR_MEDICION_SEMANAL` (denormalizado desde `S_SEMANA_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | C2:BV2 (cabeceras "Semana N") — derivado: semanas 1-52 = año 2025, semanas 1-19 de la segunda mitad = año 2026 |
| `semana_nro` | `BR_MEDICION_SEMANAL` (denormalizado desde `S_SEMANA_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | C2:BV2 — extraído del texto "Semana NN" |
| `ambito` | `BR_MEDICION_SEMANAL` (constante por diseño del bridge) | — | — | Valor fijo `fiscalizacion` asignado durante el ETL |
