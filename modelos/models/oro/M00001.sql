{#-
    M00001 — M_RANKING_SEMANAL
    Datamart oro: una fila por (planta, punto, semana) con la concentración medida.
    Sirve a las preguntas P00001 (punto más alto) y P00002 (punto más bajo).
    Ámbito: fiscalizacion (denormalizado como literal).

    Construcción desde silver:
      L_MEDICION  +  S_MEDICION_VALOR  (hecho atómico de medición)
      L_PUNTO_PLANTA + S_PLANTA_DESCR  (planta canónica)
      L_PUNTO_MAQGEN + S_MAQGEN_DESCR  (máquina generadora asociada)
      S_PUNTO_DESCR                    (nombre del punto)
      S_SEMANA_DESCR                   (fecha calendario)

    Los filtros particulares de cada pregunta (top 1 más alto / más bajo) viven en
    configuracion/reglas/consultas/P00001_M00001.sql y P00002_M00001.sql.
-#}
{{
    config(
        tags=['capa:oro', 'dominio:codelco_andina']
    )
}}

WITH medicion AS (
    SELECT
        lm.huella_registro          AS medicion_hk,
        lm.ent_punto_medicion_hk,
        lm.ent_semana_hk,
        lm.punto_nro,
        lm.anio,
        lm.semana_nro,
        sm.concentracion_mg_m3,
        sm.fecha_medicion,
        sm.hora_inicio,
        sm.hora_termino,
        sm.estado,
        sm.motivo_no_medicion
    FROM {{ ref('silver_relacion_medicion') }} lm
    LEFT JOIN {{ ref('silver_detalle_medicion') }} sm
        ON lm.huella_registro = sm.huella_registro
       AND sm.valid_to IS NULL
),

punto AS (
    SELECT
        sp.huella_registro          AS ent_punto_medicion_hk,
        sp.nombre_punto,
        sp.descripcion_punto,
        sp.tipo_punto
    FROM {{ ref('silver_detalle_punto_medicion') }} sp
    WHERE sp.valid_to IS NULL
),

planta AS (
    SELECT
        lpp.ent_punto_medicion_hk,
        spd.nombre_planta,
        lpp.planta_canon
    FROM {{ ref('silver_relacion_punto_planta') }} lpp
    LEFT JOIN {{ ref('silver_detalle_planta') }} spd
        ON {{ huella_registro(['lpp.planta_canon']) }} = spd.huella_registro
       AND spd.valid_to IS NULL
),

maqgen AS (
    SELECT
        lpm.ent_punto_medicion_hk,
        smg.maquina_gen_nombre,
        lpm.maquina_gen_codigo
    FROM {{ ref('silver_relacion_punto_maqgen') }} lpm
    LEFT JOIN {{ ref('silver_detalle_maquina_generadora') }} smg
        ON {{ huella_registro(['lpm.maquina_gen_codigo']) }} = smg.huella_registro
       AND smg.valid_to IS NULL
),

semana AS (
    SELECT
        ss.huella_registro          AS ent_semana_hk,
        ss.fecha_inicio_semana,
        ss.fecha_fin_semana
    FROM {{ ref('silver_detalle_semana') }} ss
    WHERE ss.valid_to IS NULL
)

SELECT
    p.planta_canon,
    p.nombre_planta,
    m.punto_nro,
    pt.nombre_punto,
    pt.descripcion_punto,
    pt.tipo_punto,
    mg.maquina_gen_codigo,
    mg.maquina_gen_nombre,
    m.anio,
    m.semana_nro,
    s.fecha_inicio_semana,
    s.fecha_fin_semana,
    m.fecha_medicion,
    m.hora_inicio,
    m.hora_termino,
    m.concentracion_mg_m3,
    m.estado,
    m.motivo_no_medicion,
    'fiscalizacion'::text   AS ambito
FROM medicion m
LEFT JOIN punto  pt ON m.ent_punto_medicion_hk = pt.ent_punto_medicion_hk
LEFT JOIN planta p  ON m.ent_punto_medicion_hk = p.ent_punto_medicion_hk
LEFT JOIN maqgen mg ON m.ent_punto_medicion_hk = mg.ent_punto_medicion_hk
LEFT JOIN semana s  ON m.ent_semana_hk         = s.ent_semana_hk
