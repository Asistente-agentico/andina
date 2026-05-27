-- P00013 — ¿Entre qué semanas ocurre el mayor número de puntos con alto grado de polución en la planta X?
-- Identifica la ventana móvil de 4 semanas con más eventos sobre 2.5 mg/m³ para la planta indicada.
WITH eventos_altos AS (
    SELECT anio, semana_nro
    FROM {{ mart('M00005') }}
    WHERE planta_canon = {{ planta }}
      AND concentracion_mg_m3 >= 2.5
),
por_semana AS (
    SELECT anio, semana_nro, COUNT(*) AS n_altos
    FROM eventos_altos
    GROUP BY anio, semana_nro
)
SELECT
    {{ planta }} AS planta_canon,
    anio,
    semana_nro       AS semana_inicio,
    semana_nro + 3   AS semana_fin,
    SUM(n_altos) OVER (
        PARTITION BY anio
        ORDER BY semana_nro
        ROWS BETWEEN CURRENT ROW AND 3 FOLLOWING
    ) AS n_altos_ventana
FROM por_semana
ORDER BY n_altos_ventana DESC NULLS LAST
LIMIT 1
