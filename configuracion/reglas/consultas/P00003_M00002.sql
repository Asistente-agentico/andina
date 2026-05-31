-- P00003 — ¿Cuál fue el promedio de medición en la planta X?
-- M00002 viene pre-agregado por (planta, semana). Para el promedio histórico de la planta
-- se pondera por n_mediciones (promediar promedios sin ponderar sesga el resultado).
SELECT
    planta_canon,
    SUM(n_mediciones)                                                  AS n_mediciones,
    ROUND((SUM(promedio_mg_m3 * n_mediciones) / NULLIF(SUM(n_mediciones),0))::numeric, 3) AS promedio_mg_m3,
    ROUND(MAX(maximo_mg_m3)::numeric, 3)                               AS maximo_mg_m3,
    ROUND(MIN(minimo_mg_m3)::numeric, 3)                               AS minimo_mg_m3,
    ambito
FROM {{ mart('M00002') }}
GROUP BY planta_canon, ambito
