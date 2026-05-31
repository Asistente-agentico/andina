-- P00019 — ¿Quién realizó la mantención de la máquina X?
-- Devuelve las OT ejecutadas (cumpl_prog = 1) con su responsable (equipo/contratista),
-- en el contexto del punto de control.
SELECT
    punto_nro,
    nombre_punto,
    equipo_denom,
    orden_nro,
    anio,
    semana_nro,
    responsable_nombre
FROM {{ mart('M00009') }}
WHERE equipo_denom ILIKE {{ maquina }}
  AND cumpl_prog = 1
  AND ({{ punto }} IS NULL OR punto_nro = {{ punto }})
ORDER BY anio DESC, semana_nro DESC
