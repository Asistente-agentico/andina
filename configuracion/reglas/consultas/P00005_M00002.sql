-- P00005 — ¿Cuál es la planta con los puntos de medición más altos?
-- Planta con el promedio histórico más alto (ponderado por n_mediciones) sobre M00002.
SELECT
    planta_canon,
    SUM(n_mediciones)                                                  AS n_mediciones,
    ROUND((SUM(promedio_mg_m3 * n_mediciones) / NULLIF(SUM(n_mediciones),0))::numeric, 3) AS promedio_mg_m3,
    ROUND(MAX(maximo_mg_m3)::numeric, 3)                               AS pico_mg_m3,
    ambito
FROM {{ mart('M00002') }}
GROUP BY planta_canon, ambito
ORDER BY promedio_mg_m3 DESC
LIMIT 1
