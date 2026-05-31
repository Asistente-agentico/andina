-- P00006 — ¿Cuál es la planta con los puntos de medición más bajos?
-- Planta con el promedio histórico más bajo (ponderado), excluyendo semanas de promedio cero.
SELECT
    planta_canon,
    SUM(n_mediciones)                                                  AS n_mediciones,
    ROUND((SUM(promedio_mg_m3 * n_mediciones) / NULLIF(SUM(n_mediciones),0))::numeric, 3) AS promedio_mg_m3,
    ROUND(MIN(minimo_mg_m3)::numeric, 3)                               AS minimo_mg_m3,
    ambito
FROM {{ mart('M00002') }}
WHERE promedio_mg_m3 > 0
GROUP BY planta_canon, ambito
ORDER BY promedio_mg_m3 ASC
LIMIT 1
