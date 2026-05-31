-- P00022 — ¿Cuánto tiempo se planificó para la mantención y cuánto tomó realmente?
-- Compara HH y duración planificadas vs reales para la OT o máquina, en contexto del punto.
SELECT
    punto_nro,
    nombre_punto,
    orden_nro,
    equipo_denom,
    ot_texto_breve,
    anio,
    semana_nro,
    hh_planificadas,
    hh_reales,
    duracion_planificada,
    duracion_real,
    (hh_reales - hh_planificadas) AS desviacion_hh
FROM {{ mart('M00009') }}
WHERE ( orden_nro = {{ orden_nro }} OR equipo_denom ILIKE {{ maquina }} )
  AND ({{ punto }} IS NULL OR punto_nro = {{ punto }})
ORDER BY anio DESC, semana_nro DESC
