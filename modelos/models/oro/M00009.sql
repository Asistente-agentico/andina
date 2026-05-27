{#-
    M00009 — M_EJECUCION_OT
    Datamart oro: OT del Programa de ventilación que SÍ se ejecutaron, con sus datos reales.
    Sirve a las preguntas:
      P00018 — para el sistema X, ¿cuándo se realizó la última mantención?
      P00019 — ¿quién realizó la mantención de la máquina X?
      P00020 — ¿cuántas personas trabajaron en la mantención?
      P00021 — ¿en qué fecha se realizó la última mantención?
      P00022 — ¿cuánto tiempo se planificó vs cuánto tomó realmente?
    Ámbito: mantencion (denormalizado como literal).

    Construcción desde silver:
      L_OT_MAQCTRL                          (asociación OT - máquina control - semana)
      S_OT_DESCR                            (texto breve de la OT)
      S_OT_PROGRAMACION                     (HH y duración planificadas)
      S_OT_EJECUCION                        (HH, personal y duración reales; cumpl_prog = 1)
      L_OT_RESPONSABLE + S_PERSONA_DESCR    (responsable que ejecutó la OT)
      S_MAQCTRL_DESCR                       (denom, tipo, familia)
      L_PLANTA_TIPO_EQUIPO + S_PLANTA_DESCR (planta canónica)

    El filtro fundamental cumpl_prog = 1 vive aquí (define el dataset del datamart).
    Filtros adicionales (por OT, por máquina, LIMIT 1 para última) viven en
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
        soe.cumpl_prog,
        soe.hh_reales,
        soe.personal_real,
        soe.duracion_real,
        soe.adherencia_prog,
        soe.dia_ejecutado
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
    WHERE soe.cumpl_prog = 1
),

responsable AS (
    SELECT
        lor.ent_orden_trabajo_hk,
        sp.nombre_completo          AS responsable_nombre,
        sp.tipo_persona              AS responsable_tipo
    FROM {{ ref('silver_relacion_ot_responsable') }} lor
    LEFT JOIN {{ ref('silver_detalle_persona') }} sp
        ON lor.ent_persona_hk = sp.huella_registro
       AND sp.valid_to IS NULL
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
    o.hh_reales,
    o.personal_real,
    o.duracion_real,
    o.adherencia_prog,
    o.dia_ejecutado,
    r.responsable_nombre,
    r.responsable_tipo,
    'mantencion'::text   AS ambito
FROM ot o
LEFT JOIN responsable r ON o.ent_orden_trabajo_hk         = r.ent_orden_trabajo_hk
LEFT JOIN maqctrl     mc ON o.ent_maquina_control_polvo_hk = mc.ent_maquina_control_polvo_hk
LEFT JOIN planta      pl ON mc.tipo_equipo                 = pl.tipo_equipo_codigo
