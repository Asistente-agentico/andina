{#-
    M00006 — M_TENDENCIAS
    Datamart oro: serie temporal de concentraciones por (planta, punto, año, semana) para
    calcular tendencias lineales por planta.
    Sirve a la pregunta:
      P00017 — ¿cuál es la planta con tendencia creciente y cuáles son sus puntos?
    Ámbito: fiscalizacion (denormalizado como literal).

    Construcción desde silver:
      L_MEDICION + S_MEDICION_VALOR     (serie de concentraciones)
      L_PUNTO_PLANTA                    (planta canónica)
      S_PUNTO_DESCR                     (nombre del punto)

    Los cálculos particulares (REGR_SLOPE, REGR_R2, LIMIT 1) viven en
    configuracion/reglas/consultas/.
-#}
{{
    config(
        tags=['capa:oro', 'dominio:codelco_andina']
    )
}}

WITH medicion AS (
    SELECT
        lm.ent_punto_medicion_hk,
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
)

SELECT
    p.planta_canon,
    m.punto_nro,
    pt.nombre_punto,
    m.anio,
    m.semana_nro,
    m.concentracion_mg_m3,
    m.estado,
    'fiscalizacion'::text   AS ambito
FROM medicion m
LEFT JOIN punto  pt ON m.ent_punto_medicion_hk = pt.ent_punto_medicion_hk
LEFT JOIN planta p  ON m.ent_punto_medicion_hk = p.ent_punto_medicion_hk
