-- P00004 — ¿Cuál fue el promedio considerando todas las plantas?
-- Devuelve una fila por planta y una fila de total global (planta_canon = NULL).
SELECT
    planta_canon,
    COUNT(*)                                    AS n_mediciones,
    ROUND(AVG(concentracion_mg_m3)::numeric, 3) AS promedio_mg_m3,
    ROUND(MAX(concentracion_mg_m3)::numeric, 3) AS maximo_mg_m3,
    ROUND(MIN(concentracion_mg_m3)::numeric, 3) AS minimo_mg_m3,
    ambito
FROM {{ mart('M00002') }}
WHERE estado = 'medido'
GROUP BY ROLLUP(planta_canon), ambito
ORDER BY planta_canon NULLS LAST
