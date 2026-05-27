-- P00014 — ¿Entre qué semanas ocurre el mayor número de altas concentraciones en el punto X?
-- Devuelve el rango de semanas con altas concentraciones (>= 2.5 mg/m³) por año para el punto indicado.
SELECT
    {{ punto_nro }} AS punto_nro,
    anio,
    MIN(semana_nro) AS desde,
    MAX(semana_nro) AS hasta,
    COUNT(*)        AS n_eventos
FROM {{ mart('M00005') }}
WHERE punto_nro = {{ punto_nro }}
  AND concentracion_mg_m3 >= 2.5
GROUP BY anio
ORDER BY anio
