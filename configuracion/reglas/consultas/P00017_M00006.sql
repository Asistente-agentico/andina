-- P00017 — ¿Cuál de todas las plantas tiene la tendencia de crecer en polución alto y cuáles son esos puntos de medición?
-- Calcula la pendiente lineal de la concentración semanal por planta y devuelve los puntos de la planta con mayor pendiente positiva.
WITH prom_planta_semana AS (
    SELECT planta_canon, semana_nro, AVG(concentracion_mg_m3) AS prom
    FROM {{ mart('M00006') }}
    WHERE estado = 'medido'
    GROUP BY planta_canon, semana_nro
),
tendencia AS (
    SELECT planta_canon,
           REGR_SLOPE(prom, semana_nro) AS pendiente,
           REGR_R2(prom, semana_nro)    AS r2
    FROM prom_planta_semana
    GROUP BY planta_canon
),
top_planta AS (
    SELECT planta_canon, pendiente, r2
    FROM tendencia
    WHERE pendiente > 0
    ORDER BY pendiente DESC
    LIMIT 1
)
SELECT
    tp.planta_canon,
    tp.pendiente,
    tp.r2,
    m.punto_nro,
    m.nombre_punto,
    ROUND(AVG(m.concentracion_mg_m3)::numeric, 3) AS promedio_punto
FROM top_planta tp
JOIN {{ mart('M00006') }} m
     ON m.planta_canon = tp.planta_canon
WHERE m.estado = 'medido'
GROUP BY tp.planta_canon, tp.pendiente, tp.r2, m.punto_nro, m.nombre_punto
ORDER BY promedio_punto DESC
