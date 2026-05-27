-- P00020 — ¿Cuántas personas trabajaron en la mantención?
-- Devuelve el personal real vs el planificado para la OT o máquina indicada.
SELECT
    orden_nro,
    equipo_denom,
    anio,
    semana_nro,
    personal_real AS personas_que_trabajaron,
    personal_prog AS personas_planificadas
FROM {{ mart('M00009') }}
WHERE orden_nro = {{ orden_nro }}
   OR equipo_denom ILIKE {{ maquina }}
