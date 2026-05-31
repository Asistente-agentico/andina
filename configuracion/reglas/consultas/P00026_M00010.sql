-- P00026 — ¿Qué trabajo involucran las Órdenes de Trabajo X, Y, Z?
-- Descripción del trabajo planificado para las OT consultadas, en contexto del punto.
SELECT
    punto_nro,
    nombre_punto,
    orden_nro,
    ot_texto_breve,
    equipo_denom,
    ubicacion_tecnica,
    planta_canon,
    tipo_equipo,
    inicio_programado,
    hh_planificadas,
    anio,
    semana_nro
FROM {{ mart('M00010') }}
WHERE orden_nro IN ({{ orden_x }}, {{ orden_y }}, {{ orden_z }})
  AND ({{ punto }} IS NULL OR punto_nro = {{ punto }})
ORDER BY orden_nro
