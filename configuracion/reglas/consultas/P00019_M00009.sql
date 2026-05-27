-- P00019 — ¿Quién realizó la mantención de la máquina X?
-- Devuelve las OT ejecutadas (cumpl_prog = 1) para la máquina indicada con sus responsables.
SELECT
    equipo_denom,
    orden_nro,
    anio,
    semana_nro,
    responsable_nombre
FROM {{ mart('M00009') }}
WHERE equipo_denom ILIKE {{ maquina }}
  AND cumpl_prog = 1
ORDER BY anio DESC, semana_nro DESC
