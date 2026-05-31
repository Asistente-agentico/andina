{#-
    M00005 — M_VENTANAS_TEMPORALES
    Datamart oro: serie de mediciones por (planta, punto, semana) para identificar
    ventanas temporales de alta o baja polución.
    Sirve a las preguntas:
      P00013 — entre qué semanas ocurre el mayor número de puntos con alta polución en planta X
      P00014 — entre qué semanas ocurre el mayor número de altas concentraciones en el punto X
      P00015 — entre qué semanas ocurre el mayor número de bajas concentraciones en el punto X
      P00016 — entre qué semanas ocurre el mayor número de puntos con baja polución en planta X
    Ámbito: fiscalizacion (denormalizado como literal).

    Construcción desde silver:
      L_MEDICION + S_MEDICION_VALOR     (concentraciones por punto y semana)
      L_PUNTO_PLANTA                    (planta canónica)
      S_PUNTO_DESCR                     (nombre del punto)
      S_SEMANA_DESCR                    (fecha calendario)

    Los filtros particulares (ventana móvil de 4 semanas, umbrales >= 2.5 o BETWEEN 0.01 y 1.0,
    LIMIT 1) viven en configuracion/reglas/consultas/.
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
        sm.concentracion_mg_m3,
        sm.estado
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
    m.punto_nro,
    pt.nombre_punto,
    m.anio,
    m.semana_nro,
    s.fecha_inicio_semana,
    s.fecha_fin_semana,
    m.concentracion_mg_m3,
    m.estado,
    'fiscalizacion'::text   AS ambito
FROM medicion m
LEFT JOIN punto  pt ON m.ent_punto_medicion_hk = pt.ent_punto_medicion_hk
LEFT JOIN planta p  ON m.ent_punto_medicion_hk = p.ent_punto_medicion_hk
LEFT JOIN semana s  ON m.ent_semana_hk         = s.ent_semana_hk
