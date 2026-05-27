-- P00011 — ¿Por qué no se tomó la medición en la fecha X?
-- Devuelve las mediciones con estado 'no_medido' junto con el motivo de no-medición.
SELECT
    planta_canon,
    punto_nro,
    nombre_punto,
    anio,
    semana_nro,
    fecha_inicio_semana,
    estado,
    motivo_no_medicion
FROM {{ mart('M00003') }}
WHERE estado = 'no_medido'
  AND ({{ fecha }} IS NULL OR fecha_inicio_semana <= {{ fecha }}::date)
ORDER BY planta_canon, punto_nro, anio, semana_nro
