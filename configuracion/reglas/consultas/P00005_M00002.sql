-- P00005 — ¿Cuál es la planta con los puntos de medición más altos?
-- Devuelve la planta con el promedio más alto entre todas (LIMIT 1).
SELECT
    planta_canon,
    COUNT(*)                                    AS n_mediciones,
    ROUND(AVG(concentracion_mg_m3)::numeric, 3) AS promedio_mg_m3,
    ROUND(MAX(concentracion_mg_m3)::numeric, 3) AS pico_mg_m3,
    ambito
FROM {{ mart('M00002') }}
WHERE estado = 'medido'
GROUP BY planta_canon, ambito
ORDER BY promedio_mg_m3 DESC
LIMIT 1
