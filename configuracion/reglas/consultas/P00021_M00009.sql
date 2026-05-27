-- P00021 — ¿En qué fecha se realizó la última mantención a la máquina / sistema?
-- Devuelve la fecha de la última OT ejecutada (cumpl_prog = 1) para la máquina indicada.
SELECT
    equipo_denom,
    orden_nro,
    inicio_programado AS fecha_planificada,
    anio,
    semana_nro
FROM {{ mart('M00009') }}
WHERE equipo_denom ILIKE {{ maquina }}
  AND cumpl_prog = 1
ORDER BY anio DESC, semana_nro DESC
LIMIT 1
