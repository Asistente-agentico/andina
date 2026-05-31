-- P00025 — ¿Cuáles son las Órdenes de Trabajo que actualmente están siendo ejecutadas?
-- OT de la semana en curso aún no cerradas (cumpl_prog NULL o 0), en contexto del punto.
SELECT
    punto_nro,
    nombre_punto,
    orden_nro,
    ot_texto_breve,
    equipo_denom,
    planta_canon,
    inicio_programado,
    anio,
    semana_nro
FROM {{ mart('M00010') }}
WHERE ( cumpl_prog IS NULL OR cumpl_prog = 0 )
  AND anio = {{ anio_actual }}
  AND semana_nro = {{ semana_actual }}
  AND ({{ punto }} IS NULL OR punto_nro = {{ punto }})
ORDER BY inicio_programado
