{#-
    M00002 — M_PROMEDIOS_PLANTA
    Datamart oro: una fila por (planta, semana) con estadísticas agregadas de concentración.
    Sirve a las preguntas:
      P00003 — promedio de una planta
      P00004 — promedio de todas las plantas (con ROLLUP en la consulta)
      P00005 — planta con puntos más altos
      P00006 — planta con puntos más bajos
    Ámbito: fiscalizacion (denormalizado como literal).

    Construcción desde silver:
      L_MEDICION + S_MEDICION_VALOR     (concentraciones)
      L_PUNTO_PLANTA                    (asociación punto-planta)
      S_PLANTA_DESCR                    (nombre canónico)

    Los filtros particulares de cada pregunta (filtrar planta X, LIMIT 1, etc.) viven
    en configuracion/reglas/consultas/.
-#}
{{
    config(
        tags=['capa:oro', 'dominio:codelco_andina']
    )
}}

WITH medicion AS (
    SELECT
        lm.ent_punto_medicion_hk,
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

planta AS (
    SELECT
        lpp.ent_punto_medicion_hk,
        lpp.planta_canon,
        spd.nombre_planta
    FROM {{ ref('silver_relacion_punto_planta') }} lpp
    LEFT JOIN {{ ref('silver_detalle_planta') }} spd
        ON {{ huella_registro(['lpp.planta_canon']) }} = spd.huella_registro
       AND spd.valid_to IS NULL
)

SELECT
    p.planta_canon,
    p.nombre_planta,
    m.anio,
    m.semana_nro,
    COUNT(*)                                          AS n_mediciones,
    ROUND(AVG(m.concentracion_mg_m3)::numeric, 3)     AS promedio_mg_m3,
    ROUND(MAX(m.concentracion_mg_m3)::numeric, 3)     AS maximo_mg_m3,
    ROUND(MIN(m.concentracion_mg_m3)::numeric, 3)     AS minimo_mg_m3,
    'fiscalizacion'::text                              AS ambito
FROM medicion m
LEFT JOIN planta p ON m.ent_punto_medicion_hk = p.ent_punto_medicion_hk
GROUP BY p.planta_canon, p.nombre_planta, m.anio, m.semana_nro
