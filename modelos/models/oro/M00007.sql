{#-
    M00007 — M_CAUSA_RAIZ
    Datamart oro: causas contribuyentes que explican un pico de polvo en un punto/semana.
    Combina datos de fiscalización (condiciones observadas) y mantención (OT no ejecutadas).
    Sirve a las preguntas:
      P00007 — ¿por qué el punto X tiene altos niveles?
      P00008 — ¿por qué la máquina X no tuvo mantención?
    Ámbito: cruzado (combina fiscalizacion + mantencion en el mismo datamart).

    Construcción desde silver:
      L_MEDICION + S_MEDICION_VALOR              (concentración del punto en la semana)
      L_PUNTO_PLANTA                              (planta canónica)
      S_PUNTO_DESCR                               (nombre del punto)
      L_PUNTO_MAQGEN + S_MAQGEN_DESCR             (máquina generadora — familia A)
      L_PUNTO_COMPONENTE + S_COMPONENTE_DESCR + S_COMPONENTE_ESTADO
                                                  (chute/pieza específica que mide el punto y su estado — familia A)
      L_CONDICION_OBSERVADA + S_CONDICION_ESTADO  (condiciones registradas en el punto)
      S_CONDICION_TIPO_DESCR                      (familia causal y peso por defecto)
      L_CONDICION_PROBLEMA + S_PROBLEMA_DESCR     (problema raíz al que apunta la condición)
      L_PUNTO_MAQCTRL + S_MAQCTRL_DESCR           (máquinas de control que cubren el punto)
      L_OT_MAQCTRL + S_OT_DESCR + S_OT_PROGRAMACION + S_OT_EJECUCION + S_OT_NO_EJECUCION (OT asociadas, familia B)

    Los cálculos de peso ponderado, es_causa_principal y los dos queries diferentes (P00007 por
    punto, P00008 por máquina) viven en configuracion/reglas/consultas/.
-#}
{{
    config(
        tags=['capa:oro', 'dominio:codelco_andina']
    )
}}

WITH medicion AS (
    SELECT
        lm.ent_punto_medicion_hk,
        lm.ent_semana_hk,
        lm.punto_nro,
        lm.anio,
        lm.semana_nro,
        sm.concentracion_mg_m3
    FROM {{ ref('silver_relacion_medicion') }} lm
    LEFT JOIN {{ ref('silver_detalle_medicion') }} sm
        ON lm.huella_registro = sm.huella_registro
       AND sm.valid_to IS NULL
    WHERE sm.estado = 'medido'
),

punto AS (
    SELECT
        sp.huella_registro          AS ent_punto_medicion_hk,
        sp.nombre_punto
    FROM {{ ref('silver_detalle_punto_medicion') }} sp
    WHERE sp.valid_to IS NULL
),

planta AS (
    SELECT
        lpp.ent_punto_medicion_hk,
        lpp.planta_canon
    FROM {{ ref('silver_relacion_punto_planta') }} lpp
),

-- Componente estructural (chute/pieza) que mide el punto + su estado semanal.
-- Permite distinguir dos puntos sobre la misma correa que miden chutes distintos.
componente AS (
    SELECT
        lpc.ent_punto_medicion_hk,
        lpc.componente_codigo,
        sdc.componente_nombre,
        sdc.tipo_componente,
        sce.estado_actual            AS estado_componente
    FROM {{ ref('silver_relacion_punto_componente') }} lpc
    LEFT JOIN {{ ref('silver_detalle_componente') }} sdc
        ON lpc.ent_componente_estructural_hk = sdc.huella_registro
       AND sdc.valid_to IS NULL
    LEFT JOIN {{ ref('silver_detalle_componente_estado') }} sce
        ON lpc.ent_componente_estructural_hk = sce.huella_registro
       AND sce.valid_to IS NULL
),

condicion AS (
    SELECT
        lco.ent_punto_medicion_hk,
        lco.ent_semana_hk,
        lco.condicion_codigo,
        stc.condicion_nombre,
        spr.familia_causa,
        stc.peso_causa_default,
        sce.severidad,
        spr.problema_raiz_nombre
    FROM {{ ref('silver_relacion_condicion_observada') }} lco
    LEFT JOIN {{ ref('silver_detalle_condicion_estado') }} sce
        ON lco.huella_registro = sce.huella_registro
       AND sce.valid_to IS NULL
    LEFT JOIN {{ ref('silver_detalle_condicion_tipo') }} stc
        ON {{ huella_registro(['lco.condicion_codigo']) }} = stc.huella_registro
       AND stc.valid_to IS NULL
    LEFT JOIN {{ ref('silver_relacion_condicion_problema') }} lcp
        ON lco.condicion_codigo = lcp.condicion_codigo
    LEFT JOIN {{ ref('silver_detalle_problema_raiz') }} spr
        ON {{ huella_registro(['lcp.problema_raiz_codigo']) }} = spr.huella_registro
       AND spr.valid_to IS NULL
),

ot_maqctrl AS (
    SELECT
        lpmc.ent_punto_medicion_hk,
        lom.ent_semana_hk,
        lom.orden_nro,
        sod.ot_texto_breve,
        smc.equipo_denom,
        smc.tipo_equipo,
        smc.familia_equipo,
        soe.cumpl_prog,
        sone.motivo_no_ejecucion,
        sone.peso_motivo,
        sone.fecha_reprogramacion
    FROM {{ ref('silver_relacion_punto_maqctrl') }} lpmc
    LEFT JOIN {{ ref('silver_relacion_ot_maqctrl') }} lom
        ON lpmc.ubicacion_tecnica = lom.ubicacion_tecnica
    LEFT JOIN {{ ref('silver_detalle_ot_descr') }} sod
        ON {{ huella_registro(['lom.orden_nro']) }} = sod.huella_registro
       AND sod.valid_to IS NULL
    LEFT JOIN {{ ref('silver_detalle_maquina_control_polvo') }} smc
        ON {{ huella_registro(['lpmc.ubicacion_tecnica']) }} = smc.huella_registro
       AND smc.valid_to IS NULL
    LEFT JOIN {{ ref('silver_detalle_ot_ejecucion') }} soe
        ON {{ huella_registro(['lom.orden_nro']) }} = soe.huella_registro
       AND soe.valid_to IS NULL
    LEFT JOIN {{ ref('silver_detalle_ot_no_ejecucion') }} sone
        ON {{ huella_registro(['lom.orden_nro']) }} = sone.huella_registro
       AND sone.valid_to IS NULL
)

-- Filas familia A y C: condiciones observadas (incluye humectacion/aseo/ambiental)
SELECT
    p.planta_canon,
    m.punto_nro,
    pt.nombre_punto,
    m.anio,
    m.semana_nro,
    m.concentracion_mg_m3,
    'condicion'::text               AS tipo_causa,
    c.condicion_nombre              AS causa_descripcion,
    c.condicion_nombre,
    c.condicion_codigo,
    c.severidad,
    c.problema_raiz_nombre,
    c.familia_causa,
    -- Enriquecimiento con el componente estructural (chute/pieza) — Opción A
    cmp.componente_codigo,
    cmp.componente_nombre,
    cmp.tipo_componente,
    cmp.estado_componente,
    NULL::text                      AS equipo_denom,
    NULL::text                      AS tipo_equipo,
    NULL::text                      AS familia_equipo,
    NULL::text                      AS ot_relacionada,
    NULL::text                      AS motivo_no_ejecucion,
    NULL::date                      AS fecha_reprogramacion,
    c.peso_causa_default            AS peso_causa,
    CASE WHEN c.peso_causa_default >= 0.80 THEN true ELSE false END AS es_causa_principal,
    'cruzado'::text                 AS ambito
FROM medicion m
LEFT JOIN punto      pt  ON m.ent_punto_medicion_hk = pt.ent_punto_medicion_hk
LEFT JOIN planta     p   ON m.ent_punto_medicion_hk = p.ent_punto_medicion_hk
LEFT JOIN componente cmp ON m.ent_punto_medicion_hk = cmp.ent_punto_medicion_hk
INNER JOIN condicion c
       ON m.ent_punto_medicion_hk = c.ent_punto_medicion_hk
      AND m.ent_semana_hk         = c.ent_semana_hk

UNION ALL

-- Filas familia B: OT no ejecutadas sobre las máquinas de control que cubren el punto
SELECT
    p.planta_canon,
    m.punto_nro,
    pt.nombre_punto,
    m.anio,
    m.semana_nro,
    m.concentracion_mg_m3,
    'mantencion'::text              AS tipo_causa,
    o.ot_texto_breve                AS causa_descripcion,
    NULL::text                      AS condicion_nombre,
    NULL::text                      AS condicion_codigo,
    NULL::text                      AS severidad,
    'Máquina de control detenida'::text AS problema_raiz_nombre,
    'B'::text                       AS familia_causa,
    -- Columnas de componente: no aplican a la familia B (OT)
    NULL::text                      AS componente_codigo,
    NULL::text                      AS componente_nombre,
    NULL::text                      AS tipo_componente,
    NULL::text                      AS estado_componente,
    o.equipo_denom,
    o.tipo_equipo,
    o.familia_equipo,
    o.orden_nro::text               AS ot_relacionada,
    o.motivo_no_ejecucion,
    o.fecha_reprogramacion,
    o.peso_motivo                   AS peso_causa,
    CASE WHEN o.peso_motivo >= 0.80 THEN true ELSE false END AS es_causa_principal,
    'cruzado'::text                 AS ambito
FROM medicion m
LEFT JOIN punto      pt ON m.ent_punto_medicion_hk = pt.ent_punto_medicion_hk
LEFT JOIN planta     p  ON m.ent_punto_medicion_hk = p.ent_punto_medicion_hk
INNER JOIN ot_maqctrl o
       ON m.ent_punto_medicion_hk = o.ent_punto_medicion_hk
      AND m.ent_semana_hk         = o.ent_semana_hk
      AND o.cumpl_prog = 0
