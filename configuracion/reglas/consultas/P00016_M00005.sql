-- P00016 — ¿Entre qué semanas ocurre el mayor número de puntos con bajo grado de polución en la planta X?
-- Identifica la ventana móvil de 4 semanas con más eventos bajos (entre 0.01 y 1.0 mg/m³) para la planta indicada.
WITH eventos_bajos AS (
    SELECT anio, semana_nro
    FROM {{ mart('M00005') }}
    WHERE planta_canon = {{ planta }}
      AND estado = 'medido'
      AND concentracion_mg_m3 BETWEEN 0.01 AND 1.0
),
por_semana AS (
    SELECT anio, semana_nro, COUNT(*) AS n_bajos
    FROM eventos_bajos
    GROUP BY anio, semana_nro
)
SELECT
    {{ planta }} AS planta_canon,
    anio,
    semana_nro       AS semana_inicio,
    semana_nro + 3   AS semana_fin,
    SUM(n_bajos) OVER (
        PARTITION BY anio
        ORDER BY semana_nro
        ROWS BETWEEN CURRENT ROW AND 3 FOLLOWING
    ) AS n_bajos_ventana
FROM por_semana
ORDER BY n_bajos_ventana DESC NULLS LAST
LIMIT 1
