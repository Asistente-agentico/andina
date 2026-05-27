-- P00015 — ¿Entre qué semanas ocurre el mayor número de bajas concentraciones en el punto X?
-- Devuelve el rango de semanas con bajas concentraciones (entre 0.01 y 1.0 mg/m³) por año para el punto indicado.
SELECT
    {{ punto_nro }} AS punto_nro,
    anio,
    MIN(semana_nro) AS desde,
    MAX(semana_nro) AS hasta,
    COUNT(*)        AS n_eventos
FROM {{ mart('M00005') }}
WHERE punto_nro = {{ punto_nro }}
  AND estado = 'medido'
  AND concentracion_mg_m3 BETWEEN 0.01 AND 1.0
GROUP BY anio
ORDER BY anio
