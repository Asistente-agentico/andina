-- P00021 — ¿En qué fecha se realizó la última mantención a la máquina / sistema?
-- Fecha de la última OT ejecutada (cumpl_prog = 1) para la máquina, en contexto del punto.
SELECT
    punto_nro,
    nombre_punto,
    equipo_denom,
    orden_nro,
    inicio_programado AS fecha_planificada,
    anio,
    semana_nro
FROM {{ mart('M00009') }}
WHERE equipo_denom ILIKE {{ maquina }}
  AND cumpl_prog = 1
  AND ({{ punto }} IS NULL OR punto_nro = {{ punto }})
ORDER BY anio DESC, semana_nro DESC
LIMIT 1
