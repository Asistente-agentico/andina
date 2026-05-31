-- P00023 — ¿En qué fecha se reprogramó la mantención?
-- Fecha original y nueva fecha de reprogramación para OT no ejecutadas, en contexto del punto.
SELECT
    punto_nro,
    nombre_punto,
    orden_nro,
    equipo_denom,
    ot_texto_breve,
    inicio_programado AS fecha_original,
    motivo_no_ejecucion,
    fecha_reprogramacion,
    anio,
    semana_nro
FROM {{ mart('M00008') }}
WHERE ( orden_nro = {{ orden_nro }} OR equipo_denom ILIKE {{ maquina }} )
  AND fecha_reprogramacion IS NOT NULL
  AND ({{ punto }} IS NULL OR punto_nro = {{ punto }})
