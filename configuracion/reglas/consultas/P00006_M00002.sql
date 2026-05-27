-- P00006 — ¿Cuál es la planta con los puntos de medición más bajos?
-- Devuelve la planta con el promedio más bajo entre todas (LIMIT 1, excluyendo ceros).
SELECT
    planta_canon,
    COUNT(*)                                    AS n_mediciones,
    ROUND(AVG(concentracion_mg_m3)::numeric, 3) AS promedio_mg_m3,
    ROUND(MIN(concentracion_mg_m3)::numeric, 3) AS minimo_mg_m3,
    ambito
FROM {{ mart('M00002') }}
WHERE estado = 'medido'
  AND concentracion_mg_m3 > 0
GROUP BY planta_canon, ambito
ORDER BY promedio_mg_m3 ASC
LIMIT 1
