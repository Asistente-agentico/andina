-- P00004 — ¿Cuál fue el promedio considerando todas las plantas?
-- Una fila por planta + una fila de total global (planta_canon = NULL via ROLLUP).
-- Promedio ponderado por n_mediciones sobre el datamart agregado M00002.
SELECT
    planta_canon,
    SUM(n_mediciones)                                                  AS n_mediciones,
    ROUND((SUM(promedio_mg_m3 * n_mediciones) / NULLIF(SUM(n_mediciones),0))::numeric, 3) AS promedio_mg_m3,
    ROUND(MAX(maximo_mg_m3)::numeric, 3)                               AS maximo_mg_m3,
    ROUND(MIN(minimo_mg_m3)::numeric, 3)                               AS minimo_mg_m3,
    ambito
FROM {{ mart('M00002') }}
GROUP BY ROLLUP(planta_canon), ambito
ORDER BY planta_canon NULLS LAST
