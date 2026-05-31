-- P00008 — ¿Por qué la máquina X no tuvo mantención?
-- Devuelve el motivo de no-ejecución para una máquina específica (familia B del modelo causal V1).
SELECT
    cr.punto_nro,
    cr.nombre_punto,
    cr.equipo_denom,
    cr.tipo_equipo,
    cr.familia_equipo,
    cr.ot_relacionada,
    cr.motivo_no_ejecucion,
    cr.fecha_reprogramacion,
    cr.planta_canon,
    cr.anio,
    cr.semana_nro
FROM {{ mart('M00007') }} cr
WHERE cr.equipo_denom ILIKE {{ maquina }}
  AND cr.familia_causa = 'B'
  AND cr.ot_relacionada IS NOT NULL
ORDER BY cr.anio DESC, cr.semana_nro DESC
