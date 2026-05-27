-- P00023 — ¿En qué fecha se reprogramó la mantención?
-- Devuelve la fecha original y la nueva fecha de reprogramación para OT no ejecutadas.
SELECT
    orden_nro,
    equipo_denom,
    ot_texto_breve,
    inicio_programado AS fecha_original,
    motivo_no_ejecucion,
    fecha_reprogramacion
FROM {{ mart('M00008') }}
WHERE ( orden_nro = {{ orden_nro }} OR equipo_denom ILIKE {{ maquina }} )
  AND fecha_reprogramacion IS NOT NULL
