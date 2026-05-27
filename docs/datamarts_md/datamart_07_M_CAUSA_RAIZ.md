# Datamart M_CAUSA_RAIZ

**Ámbito**: cruzado (fiscalización + mantención)

Este es el único datamart cruzado. Su gobernanza se materializa con la columna `ambito` denormalizada en cada fila: el gerente ve todas las filas, el jefe de fiscalización solo las de ámbito `fiscalizacion` (condiciones observadas y defectos en componentes), el jefe de mantención solo las de ámbito `mantencion` (OT no ejecutadas).

El modelo causal está anclado en el diagrama Flujo del archivo `Equipos_de_Ventilacion_V1.xlsx`: medición alta → condiciones operacionales observadas → problema raíz (chute / retorno cinta / pasillo / máquina detenida) → mantención no ejecutada (mecánica o de ventilación).

## Preguntas que responde

### ¿Por qué el punto X tiene altos niveles de medición?

Filtra por punto y devuelve **todas las causas contribuyentes** ordenadas por peso. Identifica primero la semana del pico, luego trae todas las causas registradas para ese (punto, semana).

```sql
WITH semana_pico AS (
    SELECT punto_hk, semana_hk, planta_hk, semana_nro, anio, concentracion_mg_m3
    FROM M_CAUSA_RAIZ
    WHERE punto_nro = :punto_nro
      AND concentracion_mg_m3 >= 2.5
    ORDER BY concentracion_mg_m3 DESC
    LIMIT 1
)
SELECT
    cr.tipo_causa,
    cr.causa_descripcion,
    cr.estado_valor,
    cr.severidad,
    cr.problema_raiz_nombre,
    cr.familia_causa,
    cr.tipo_equipo_recomendado,
    cr.peso_causa,
    cr.es_causa_principal
FROM semana_pico sp
JOIN M_CAUSA_RAIZ cr
     ON cr.punto_hk  = sp.punto_hk
    AND cr.semana_hk = sp.semana_hk
ORDER BY cr.es_causa_principal DESC, cr.peso_causa DESC;
```

### ¿Por qué la máquina X no tuvo mantención?

Filtra por máquina de control de polvo y devuelve **solo el motivo de no-ejecución** (familia B, OT con `cumpl_prog = 0`). Esta pregunta es la rama de mantención del modelo causal V1.

```sql
SELECT
    cr.equipo_denom,
    cr.tipo_equipo,
    cr.familia_equipo,
    cr.ot_relacionada,
    cr.motivo_no_ejecucion,
    cr.fecha_reprogramacion,
    cr.planta_canon,
    cr.anio,
    cr.semana_nro
FROM M_CAUSA_RAIZ cr
WHERE cr.equipo_denom ILIKE :maquina
  AND cr.familia_causa = 'B'
  AND cr.ot_relacionada IS NOT NULL
ORDER BY cr.anio DESC, cr.semana_nro DESC;
```

---

## Hechos

| Hecho | Campo | Tipo | Descripción |
|---|---|---|---|
| Concentración del punto en la semana del pico | `concentracion_mg_m3` | numeric | Valor que disparó la pregunta causal |
| Peso de la causa | `peso_causa` | numeric | Score 0..1 que ordena las causas contribuyentes |
| Indicador de causa principal | `es_causa_principal` | boolean | TRUE para la causa de mayor peso en cada (punto, semana) |

---

## Dimensiones

### Dimensiones (entidades de negocio con hub propio)

| Dimensión | Campo | Hub asociado | Descripción |
|---|---|---|---|
| Planta | `planta_canon` | `H_PLANTA` | Nombre canónico de la planta del punto |
| Punto de medición | `punto_nro`, `nombre_punto` | `H_PUNTO_MEDICION` | Código y nombre del punto crítico |
| Semana | `semana_nro` | `H_SEMANA` | Semana en que se observó el pico |
| Condición observada | `condicion_nombre` | `H_CONDICION_TIPO` | Una de las 8 condiciones del V1 |
| Problema raíz | `problema_raiz_nombre` | `H_PROBLEMA_RAIZ` | Fuga material chute / Polución retorno cinta / Polución pasillo |
| Componente estructural | `componente_nombre`, `tipo_componente` | `H_COMPONENTE_ESTRUCTURAL` | Aplica a familia A (chute, plancha, tapa, gualdera, cinta, raspador) |
| Máquina de control de polvo | `equipo_denom`, `tipo_equipo`, `familia_equipo` | `H_MAQUINA_CONTROL_POLVO` | Aplica a familia B. `familia_equipo` ∈ {renovacion_aire, abatidor_polvo} |
| Tipo de equipo recomendado | `tipo_equipo_recomendado` | `H_TIPO_EQUIPO_CTRL` | CDP / HDP / VEX / VIN o NULL si la mantención es mecánica |
| Orden de trabajo relacionada | `ot_relacionada` | `H_ORDEN_TRABAJO` | OT vigente cuya no-ejecución contribuye a la causa (aplica a familia B) |
| Ámbito | `ambito` | `H_AMBITO` | fiscalizacion / mantencion / cruzado (denormalizado por fila) |

### Atributos del hecho (viven en satélites)

| Atributo | Campo | Satélite origen | Descripción |
|---|---|---|---|
| Tipo de causa | `tipo_causa` | derivado de `tipo_observacion` en `L_CONDICION_OBSERVADA` | condicion_ambiental / estado_maquina_ctrl / defecto_componente |
| Estado observado | `estado_valor` | `S_CONDICION_ESTADO` o `S_COMPONENTE_ESTADO` | Operando/detenido, F.Inaceptable/F.Medio/F.Bajo, con rotura/sin sello, etc. |
| Severidad | `severidad` | `S_CONDICION_ESTADO` / `S_COMPONENTE_ESTADO` | alta / media / baja |
| Familia de causa | `familia_causa` | derivado en ETL | A (componente) / B (máquina detenida) / C (ambiental) |
| Motivo de no-ejecución | `motivo_no_ejecucion` | `S_OT_NO_EJECUCION.motivo_principal` | falta_repuestos / no_entrega_operaciones / falta_personal (solo aplica a familia B) |
| Fecha de reprogramación | `fecha_reprogramacion` | `S_OT_NO_EJECUCION.fecha_reprogramacion` | Fecha nueva para OT no ejecutada (familia B) |
| Descripción narrativa | `causa_descripcion` | concatenado en ETL | Texto compuesto: nombre del componente o equipo + estado + ubicación |

### Atributos derivados de dimensión

| Atributo | Campo | Derivado de | Descripción |
|---|---|---|---|
| Año | `anio` | `S_SEMANA_DESCR.fecha_inicio` | Año calendario de la semana del pico |

---

## Mapeo Hoja del Programa ↔ Planta canónica

El archivo `Programa_Semana_21_2026_Ventilacion.xlsx` organiza las OT por planta en hojas distintas. Cada hoja tiene su propio bloque de OT con la ejecución por día (Lunes a Domingo) y los campos `CumplProg`, `AdherenciaProg`, `HorasHombreReal`, etc.

| Hoja del Excel | `H_PLANTA.planta_canon` | Notas |
|---|---|---|
| `Chancado Fino` | Chancado Secundario y Terciario · Chancado Terciario y Cuaternario | Cubre familias del proceso fino. La denominación del equipo (col A) diferencia sub-planta. Cabecera en fila 3 |
| `Molienda` | Molienda SAG | Una sola planta. Cabecera en fila 2 |
| `Chancado Primario` | Prechancado · Nodo 3500 | Cubre las dos plantas que comparten ámbito de chancado primario. La denominación diferencia. Cabecera en fila 2 |

Las plantas **CDM Linea 1** y **CDM Linea 2** no tienen hoja dedicada en este archivo — sus OT se ubican en la hoja maestra `Programa` y se reparten según el código de ubicación técnica (`CG-NOR` → CDM L1, `CG-POE` → CDM L1, etc.).

---

## Estructuras del Data Vault que dan origen al datamart

### Hubs

| Hub | Rol |
|---|---|
| `H_PUNTO_MEDICION` | Punto cuya concentración alta dispara la pregunta |
| `H_PLANTA` | Planta del punto |
| `H_SEMANA` | Semana del pico de concentración |
| `H_CONDICION_TIPO` | Catálogo de las 8 condiciones del V1 |
| `H_PROBLEMA_RAIZ` | Los 3 problemas raíz del V1 |
| `H_COMPONENTE_ESTRUCTURAL` | Chutes, partes (plancha, tapa, gualdera, placa pórtagualdera), cinta, raspadores |
| `H_MAQUINA_CONTROL_POLVO` | Máquina detenida que contribuye a la causa (familia B) |
| `H_ORDEN_TRABAJO` | OT no ejecutada que contribuye a la causa (familia B) |
| `H_TIPO_EQUIPO_CTRL` | Catálogo de tipos: HDP, CDP, VEX, VIN, etc. |

### Links

| Link | Rol |
|---|---|
| `L_MEDICION` | Provee el pico de concentración que disparó la pregunta |
| `L_PUNTO_PLANTA` | Asocia punto con su planta |
| `L_CONDICION_OBSERVADA` | Registra las condiciones operacionales observadas en el punto en la semana del pico |
| `L_CONDICION_PROBLEMA` | Mapea cada condición a uno de los 3 problemas raíz del V1 |
| `L_COMPONENTE_PADRE` | Resuelve la jerarquía de componentes (parte → chute) cuando la causa es familia A |
| `L_COMPONENTE_MAQGEN` | Asocia el componente a su correa transportadora padre |
| `L_PUNTO_MAQCTRL` | Identifica las máquinas de control cercanas al punto (familia B) |
| `L_OT_MAQCTRL` | Enlaza la máquina detenida con su OT y semana |

### Satélites

| Satélite | Rol |
|---|---|
| `S_MEDICION_VALOR` | Aporta el `concentracion_mg_m3` del pico |
| `S_CONDICION_TIPO_DESCR` | Aporta el nombre de la condición |
| `S_CONDICION_ESTADO` | Aporta `estado_valor` y `severidad` de la condición observada |
| `S_PROBLEMA_DESCR` | Aporta el nombre del problema raíz |
| `S_COMPONENTE_DESCR` | Aporta nombre, tipo y nivel del componente estructural |
| `S_COMPONENTE_ESTADO` | Aporta `estado_general`, `sub_estado` y `severidad` del componente |
| `S_MAQCTRL_DESCR` | Aporta `denominacion`, `tipo_equipo` y `familia` de la máquina de control |
| `S_OT_DESCR` | Aporta texto breve y denominación de la OT |
| `S_OT_EJECUCION` | Aporta `cumpl_prog` (filtro fundamental: OT no ejecutada = cumpl_prog = 0) |
| `S_OT_NO_EJECUCION` | Aporta `motivo_principal` y `fecha_reprogramacion` (familia B) |

### PIT y Bridge

| Estructura | Rol |
|---|---|
| `PIT_MEDICION` | Pre-resuelve la versión vigente de `S_MEDICION_VALOR` para identificar la semana del pico |
| `PIT_OT` | Pre-resuelve los sats de la OT (descr, programación, ejecución, no-ejecución) en un solo lookup |
| `BR_MEDICION_SEMANAL` | Aporta el contexto del punto y la planta para la sub-consulta del pico |
| `BR_MANTENCION_SEMANAL` | Aporta el contexto de las OT y máquinas de control implicadas (familia B): `equipo_denom`, `tipo_equipo`, `familia_equipo`, `ot_relacionada`, `motivo_no_ejecucion`, `fecha_reprogramacion` |
| `BR_CAUSA_RAIZ` | **Bridge principal del datamart**. Pre-une cada observación con su problema raíz, componente o máquina implicada, tipo de equipo recomendado, peso de causa y bandera de causa principal. Una fila por causa contribuyente |
| `BR_PUNTO_MAQCTRL` | Resuelve la vecindad punto ↔ máquina de control para encontrar OT relevantes |

---

## Correlación dato del datamart → tabla del Data Vault → origen físico

| Campo del datamart | Tabla origen en el DV | Archivo Excel | Hoja | Coordenada / Rango |
|---|---|---|---|---|
| `concentracion_mg_m3` | `S_MEDICION_VALOR` (vía `PIT_MEDICION` y `BR_MEDICION_SEMANAL`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | C4:BV46 (matriz puntos × semanas) |
| `planta_canon` | `BR_CAUSA_RAIZ` (denormalizado desde `S_PLANTA_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | B3, B9, B14, B21, B24, B29, B39 (filas separadoras de planta, normalizadas) |
| `punto_nro` | `BR_CAUSA_RAIZ` (denormalizado desde `H_PUNTO_MEDICION`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | B4:B46 — extraído del paréntesis `(N°)`; sintético 100-122 si no tiene paréntesis |
| `nombre_punto` | `BR_CAUSA_RAIZ` (denormalizado desde `S_PUNTO_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | B4:B46 — texto antes del paréntesis |
| `anio` | `BR_CAUSA_RAIZ` (derivado de `S_SEMANA_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | C2:BV2 — semanas 1-52 = año 2025, semanas 1-19 de la segunda mitad = año 2026 |
| `semana_nro` | `BR_CAUSA_RAIZ` (denormalizado desde `S_SEMANA_DESCR`) | Puntos_Criticos_Semana_19_2026.xlsx | Resumen | C2:BV2 — extraído del texto "Semana NN" |
| `condicion_nombre` | `S_CONDICION_TIPO_DESCR` (vía `L_CONDICION_OBSERVADA` y `BR_CAUSA_RAIZ`) | Puntos_Criticos_Semana_19_2026.xlsx | Hojas de planta (Prechancado, 2° y 3°, Cuaternario, Molienda Sag, CDM (1), CDM (2), Nodo) | Filas de "Condiciones Inherentes" debajo del bloque de mediciones (etiqueta en col. A; valores intersectados con la columna de la semana) |
| `estado_valor` | `S_CONDICION_ESTADO` (vía `BR_CAUSA_RAIZ`) | Puntos_Criticos_Semana_19_2026.xlsx | Hojas de planta | Mismas filas que `condicion_nombre` — valor crudo: "Operando", "Detenido", "F. Inaceptable", "Mineral Piso", etc. |
| `severidad` | `S_CONDICION_ESTADO` o `S_COMPONENTE_ESTADO` (vía `BR_CAUSA_RAIZ`) | — | — | Derivado en ETL: "F. Inaceptable" o "Detenido" → alta; "F. Medio" → media; "F. Bajo" → baja |
| `problema_raiz_nombre` | `S_PROBLEMA_DESCR` (vía `L_CONDICION_PROBLEMA` y `BR_CAUSA_RAIZ`) | Equipos_de_Ventilacion_V1.xlsx | Flujo | Drawing1.xml — extraído de las cajas del diagrama (los 3 problemas raíz: "Fuga de Material en Chute Alimentación", "Polución de material en retorno Cinta", "Polución de material en Pasillo") |
| `familia_causa` | `BR_CAUSA_RAIZ` (derivado en ETL) | Equipos_de_Ventilacion_V1.xlsx | Flujo | A / B / C según el subárbol del diagrama: A = componente estructural, B = máquina control polvo detenida, C = ambiental |
| `componente_nombre`, `tipo_componente` | `S_COMPONENTE_DESCR` (vía `BR_CAUSA_RAIZ`) | Equipos_de_Ventilacion_V1.xlsx | Flujo | Drawing1.xml — nombres de cajas: "Chute Sector Superior", "Chute Recto", "Plancha base con Roturas", "Tapa Inspección Fuera Std", "Gualderas", "Placa Pórtagualderas", "Cinta con excesivo desgaste", "Raspadores", etc. |
| `tipo_equipo_recomendado` | `BR_CAUSA_RAIZ` (mapeo del V1) | Equipos_de_Ventilacion_V1.xlsx | Flujo | Drawing1.xml — derivado: "Colectores Detenido" → CDP, "Humectadores" → HDP, "Ventiladores Inyectores" → VIN, "Ventiladores Extractores" → VEX. NULL si la causa es componente estructural o ambiental |
| `equipo_denom` | `S_MAQCTRL_DESCR.denominacion` (vía `BR_MANTENCION_SEMANAL` y `BR_CAUSA_RAIZ`) | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Columna **A "Denominación"**, filtrado por filas con `CumplProg = 0` |
| `tipo_equipo` | `S_MAQCTRL_DESCR.tipo_equipo` (vía `BR_CAUSA_RAIZ`) | Programa_Semana_21_2026_Ventilacion.xlsx | Programa | Derivado del 5° segmento del código de ubicación técnica en columna **G "Ubicación técnica"** (HDP, CDP, EPZ, VEX, VIN, etc.) |
| `familia_equipo` | `S_MAQCTRL_DESCR.familia` (vía `BR_CAUSA_RAIZ`) | Programa_Semana_21_2026_Ventilacion.xlsx | Programa | Derivado del 4° segmento del código de ubicación técnica en columna **G "Ubicación técnica"**: `SVE` → renovacion_aire, `SCP` → abatidor_polvo |
| `ot_relacionada` (n° de OT) | `H_ORDEN_TRABAJO.orden_nro` (vía `BR_MANTENCION_SEMANAL` y `BR_CAUSA_RAIZ`) | Programa_Semana_21_2026_Ventilacion.xlsx | **Chancado Fino** (cabecera fila 3) | Columna **B "Orden"** (B4:B348) — OT de plantas Chancado Sec/Terc y Chancado Terc/Cuat |
| `ot_relacionada` (n° de OT) | `H_ORDEN_TRABAJO.orden_nro` | Programa_Semana_21_2026_Ventilacion.xlsx | **Molienda** (cabecera fila 2) | Columna **B "Orden"** (B3:B196) — OT de planta Molienda SAG |
| `ot_relacionada` (n° de OT) | `H_ORDEN_TRABAJO.orden_nro` | Programa_Semana_21_2026_Ventilacion.xlsx | **Chancado Primario** (cabecera fila 2) | Columna **B "Orden"** (B3:B57) — OT de plantas Prechancado y Nodo 3500 |
| `ot_relacionada` (n° de OT) — fallback CDM L1 y L2 | `H_ORDEN_TRABAJO.orden_nro` | Programa_Semana_21_2026_Ventilacion.xlsx | Programa | Columna **B "Orden"** (B2:B100) — solo para las plantas CDM L1 y CDM L2 que no tienen hoja propia. Planta inferida por código de ubicación técnica en col G |
| `cumpl_prog` (filtro de no-ejecución) | `S_OT_EJECUCION.cumpl_prog` | Programa_Semana_21_2026_Ventilacion.xlsx | Chancado Fino · Molienda · Chancado Primario | Columna **O "CumplProg"** — valor 0 indica OT no ejecutada (filtro de la familia B) |
| `motivo_no_ejecucion` | `S_OT_NO_EJECUCION.motivo_principal` | — | — | **Sintético** asignado en ETL para OT con `cumpl_prog = 0`. Valores: `falta_repuestos` (peso 0.90), `no_entrega_operaciones` (0.70), `falta_personal` (0.60). El ejemplo concreto del V1 (OT 9856655, "Chute Alimentación no ejecutada por falta de repuestos") sirve como caso ancla del demo |
| `fecha_reprogramacion` | `S_OT_NO_EJECUCION.fecha_reprogramacion` | — | — | **Sintético** asignado en ETL para OT con `cumpl_prog = 0`. Por defecto `inicio_programado + 7 días` |
| `peso_causa` | `BR_CAUSA_RAIZ` (calculado en ETL) | — | — | Score 0..1 según severidad y tipo de causa (componente grave = 1.00, máquina detenida + falta_repuestos = 0.90, etc.) |
| `es_causa_principal` | `BR_CAUSA_RAIZ` (calculado en ETL) | — | — | TRUE para la fila con mayor `peso_causa` en cada (punto, semana); desempate por proximidad física del equipo y luego recencia |
| `causa_descripcion` | `BR_CAUSA_RAIZ` (concatenado en ETL) | — | — | Texto narrativo: nombre del componente o equipo + estado + ubicación |
| `tipo_causa` | `BR_CAUSA_RAIZ` (derivado de `L_CONDICION_OBSERVADA.tipo_observacion`) | Puntos_Criticos_Semana_19_2026.xlsx | Hojas de planta | Derivado: filas de "Condiciones Inherentes" sobre máquinas → `estado_maquina_ctrl`; sobre estado del entorno (acumulación pasillo, aseo) → `condicion_ambiental`; sobre componentes (chute, plancha, tapa) → `defecto_componente` |
| `ambito` | `BR_CAUSA_RAIZ` (asignado por fila en ETL) | — | — | `fiscalizacion` para condiciones observadas y defectos de componentes; `mantencion` para OT no ejecutadas; `cruzado` solo en la vista del gerente |
