-- P00009 — ¿En qué fecha y horario se tomó la medición en el punto X de la planta Y?
-- Devuelve todas las mediciones del punto en la planta especificada, ordenadas cronológicamente.
SELECT
    planta_canon,
    punto_nro,
    nombre_punto,
    anio,
    semana_nro,
    fecha_medicion,
    hora_inicio,
    hora_termino,
    concentracion_mg_m3,
    estado
FROM {{ mart('M00003') }}
WHERE punto_nro = {{ punto_nro }}
  AND planta_canon = {{ planta }}
ORDER BY anio, semana_nro
