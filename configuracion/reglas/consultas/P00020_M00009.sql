-- P00020 — ¿Cuántas personas trabajaron en la mantención?
-- Personal real vs planificado para la OT o máquina indicada, en contexto del punto.
SELECT
    punto_nro,
    nombre_punto,
    orden_nro,
    equipo_denom,
    anio,
    semana_nro,
    personal_real AS personas_que_trabajaron,
    personal_prog AS personas_planificadas
FROM {{ mart('M00009') }}
WHERE ( orden_nro = {{ orden_nro }} OR equipo_denom ILIKE {{ maquina }} )
  AND ({{ punto }} IS NULL OR punto_nro = {{ punto }})
