-- P00024 — ¿Cuáles son las máquinas que no han sido mantenidas en la fecha programada?
-- Todas las OT con cumpl_prog = 0, en contexto del punto de control que cubre cada máquina.
SELECT
    punto_nro,
    nombre_punto,
    equipo_denom,
    ubicacion_tecnica,
    tipo_equipo,
    familia_equipo,
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
  AND ({{ punto }} IS NULL OR punto_nro = {{ punto }})
ORDER BY anio DESC, semana_nro DESC, planta_canon, equipo_denom
