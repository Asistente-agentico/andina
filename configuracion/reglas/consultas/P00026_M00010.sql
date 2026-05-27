-- P00026 — ¿Qué trabajo involucran las Órdenes de Trabajo X, Y, Z?
-- Devuelve la descripción del trabajo planificado para las OT consultadas por número.
SELECT
    orden_nro,
    ot_texto_breve,
    equipo_denom,
    ubicacion_tecnica,
    planta_canon,
    tipo_equipo,
    inicio_programado,
    hh_planificadas
FROM {{ mart('M00010') }}
WHERE orden_nro IN ({{ orden_x }}, {{ orden_y }}, {{ orden_z }})
ORDER BY orden_nro
