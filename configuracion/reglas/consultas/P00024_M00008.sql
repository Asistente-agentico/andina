-- P00024 — ¿Cuáles son las máquinas que no han sido mantenidas en la fecha que se programó?
-- Devuelve todas las OT con cumpl_prog = 0, ordenadas por semana y planta.
SELECT
    equipo_denom,
    ubicacion_tecnica,
    tipo_equipo,
    familia,
    planta_canon,
    orden_nro,
    ot_texto_breve,
    inicio_programado AS fecha_programada,
    motivo_no_ejecucion,
    fecha_reprogramacion,
    anio,
    semana_nro
FROM {{ mart('M00008') }}
WHERE cumpl_prog = 0
ORDER BY anio DESC, semana_nro DESC, planta_canon, equipo_denom
