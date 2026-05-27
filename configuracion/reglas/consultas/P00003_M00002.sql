-- P00003 — ¿Cuál fue el promedio de medición en la planta X?
-- Devuelve el promedio histórico de concentración por planta (filtra solo mediciones válidas).
SELECT
    planta_canon,
    COUNT(*)                                    AS n_mediciones,
    ROUND(AVG(concentracion_mg_m3)::numeric, 3) AS promedio_mg_m3,
    ROUND(MAX(concentracion_mg_m3)::numeric, 3) AS maximo_mg_m3,
    ROUND(MIN(concentracion_mg_m3)::numeric, 3) AS minimo_mg_m3,
    ambito
FROM {{ mart('M00002') }}
WHERE estado = 'medido'
GROUP BY planta_canon, ambito
