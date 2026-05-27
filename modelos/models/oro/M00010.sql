{#-
    M00010 — M_OT_EN_CURSO
    Datamart oro: OT del Programa de ventilación de la semana en curso que aún no se han cerrado
    (cumpl_prog IS NULL OR cumpl_prog = 0).
    Sirve a las preguntas:
      P00025 — ¿qué OT están actualmente en ejecución?
      P00026 — ¿qué trabajo involucran las OT X, Y, Z?
    Ámbito: mantencion (denormalizado como literal).

    Construcción desde silver:
      L_OT_MAQCTRL                          (asociación OT - máquina control - semana)
      S_OT_DESCR                            (texto breve de la OT)
      S_OT_PROGRAMACION                     (inicio_programado, HH planificadas)
      S_OT_EJECUCION                        (cumpl_prog para filtrar NULL o 0)
      S_MAQCTRL_DESCR                       (denom, tipo, familia)
      H_MAQUINA_CONTROL_POLVO               (ubicacion_tecnica)
      L_PLANTA_TIPO_EQUIPO + S_PLANTA_DESCR (planta canónica)

    Filtros particulares (semana actual con CURRENT_DATE, lista de OT específicas) viven en
    configuracion/reglas/consultas/.
-#}
{{
    config(
        tags=['capa:oro', 'dominio:codelco_andina']
    )
}}

WITH ot AS (
    SELECT
        lom.ent_orden_trabajo_hk,
        lom.ent_maquina_control_polvo_hk,
        lom.ent_semana_hk,
        lom.orden_nro,
        lom.ubicacion_tecnica,
        lom.anio,
        lom.semana_nro,
        sod.ot_texto_breve,
        sop.inicio_programado,
        sop.hh_planificadas,
        sop.duracion_planificada,
        sop.personal_prog,
        soe.cumpl_prog
    FROM {{ ref('silver_relacion_ot_maqctrl') }} lom
    LEFT JOIN {{ ref('silver_detalle_ot_descr') }} sod
        ON lom.ent_orden_trabajo_hk = sod.huella_registro
       AND sod.valid_to IS NULL
    LEFT JOIN {{ ref('silver_detalle_ot_programacion') }} sop
        ON lom.ent_orden_trabajo_hk = sop.huella_registro
       AND sop.valid_to IS NULL
    LEFT JOIN {{ ref('silver_detalle_ot_ejecucion') }} soe
        ON lom.ent_orden_trabajo_hk = soe.huella_registro
       AND soe.valid_to IS NULL
    WHERE soe.cumpl_prog IS NULL OR soe.cumpl_prog = 0
),

maqctrl AS (
    SELECT
        smc.huella_registro          AS ent_maquina_control_polvo_hk,
        smc.equipo_denom,
        smc.tipo_equipo,
        smc.familia_equipo,
        smc.sector
    FROM {{ ref('silver_detalle_maquina_control_polvo') }} smc
    WHERE smc.valid_to IS NULL
),

planta AS (
    SELECT DISTINCT
        lpt.tipo_equipo_codigo,
        lpt.planta_canon,
        spd.nombre_planta
    FROM {{ ref('silver_relacion_planta_tipo_equipo') }} lpt
    LEFT JOIN {{ ref('silver_detalle_planta') }} spd
        ON {{ huella_registro(['lpt.planta_canon']) }} = spd.huella_registro
       AND spd.valid_to IS NULL
)

SELECT
    o.orden_nro,
    o.ot_texto_breve,
    o.ubicacion_tecnica,
    mc.equipo_denom,
    mc.tipo_equipo,
    mc.familia_equipo,
    mc.sector,
    pl.planta_canon,
    pl.nombre_planta,
    o.anio,
    o.semana_nro,
    o.inicio_programado,
    o.hh_planificadas,
    o.duracion_planificada,
    o.personal_prog,
    o.cumpl_prog,
    'mantencion'::text   AS ambito
FROM ot o
LEFT JOIN maqctrl mc ON o.ent_maquina_control_polvo_hk = mc.ent_maquina_control_polvo_hk
LEFT JOIN planta  pl ON mc.tipo_equipo                 = pl.tipo_equipo_codigo
