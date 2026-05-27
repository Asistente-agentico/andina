-- P00018 — Para el sistema X, ¿cuándo se realizó la última mantención?
-- Devuelve la OT ejecutada más reciente para la máquina indicada (cumpl_prog = 1).
SELECT
    equipo_denom,
    orden_nro,
    ot_texto_breve,
    inicio_programado,
    anio,
    semana_nro,
    hh_reales,
    responsable_nombre
FROM {{ mart('M00009') }}
WHERE equipo_denom ILIKE {{ maquina }}
  AND cumpl_prog = 1
ORDER BY anio DESC, semana_nro DESC
LIMIT 1
