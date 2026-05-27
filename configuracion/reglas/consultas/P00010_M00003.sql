-- P00010 — ¿Quién fue el responsable de tomar la medición?
-- Devuelve el operador de panel y el técnico en higiene asociados a las mediciones del punto.
SELECT
    planta_canon,
    punto_nro,
    nombre_punto,
    anio,
    semana_nro,
    fecha_medicion,
    operador_panel,
    tecnico_higiene
FROM {{ mart('M00003') }}
WHERE punto_nro = {{ punto_nro }}
  AND ({{ planta }} IS NULL OR planta_canon = {{ planta }})
ORDER BY anio, semana_nro
