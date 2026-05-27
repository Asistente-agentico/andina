{#-
    M00008 — M_NO_EJECUCION_OT
    Datamart oro: OT del Programa de ventilación que NO se ejecutaron en la fecha programada.
    Sirve a las preguntas:
      P00023 — ¿en qué fecha se reprogramó la mantención?
      P00024 — ¿qué máquinas no fueron mantenidas en la fecha programada?
    Ámbito: mantencion (denormalizado como literal).

    Construcción desde silver:
      L_OT_MAQCTRL                          (asociación OT - máquina control - semana)
      S_OT_DESCR                            (texto breve de la OT)
      S_OT_PROGRAMACION                     (fecha programada planificada)
      S_OT_EJECUCION                        (cumpl_prog para filtrar = 0)
      S_OT_NO_EJECUCION                     (motivo y fecha de reprogramación)
      S_MAQCTRL_DESCR                       (descripción de la máquina: denom, tipo, familia)
      H_MAQUINA_CONTROL_POLVO               (ubicacion_tecnica)
      L_PLANTA_TIPO_EQUIPO + S_PLANTA_DESCR (planta canónica via tipo de equipo)

    El filtro fundamental cumpl_prog = 0 vive aquí (define el dataset del datamart).
    Filtros adicionales (por máquina, OT específica, semana) viven en configuracion/reglas/consultas/.
-#}
{{
    config(
        tags=['capa:oro', 'dominio:codelco_andina']
    )
}}

WITH ot AS (
    SELECT
        lom.huella_registro          AS ot_maqctrl_hk,
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
        soe.cumpl_prog,
        sone.motivo_no_ejecucion,
        sone.peso_motivo,
        sone.fecha_reprogramacion
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
    LEFT JOIN {{ ref('silver_detalle_ot_no_ejecucion') }} sone
        ON lom.ent_orden_trabajo_hk = sone.huella_registro
       AND sone.valid_to IS NULL
    WHERE soe.cumpl_prog = 0
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
    o.motivo_no_ejecucion,
    o.peso_motivo,
    o.fecha_reprogramacion,
    'mantencion'::text   AS ambito
FROM ot o
LEFT JOIN maqctrl mc ON o.ent_maquina_control_polvo_hk = mc.ent_maquina_control_polvo_hk
LEFT JOIN planta  pl ON mc.tipo_equipo                 = pl.tipo_equipo_codigo
