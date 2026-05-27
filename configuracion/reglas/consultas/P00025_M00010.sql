-- P00025 — ¿Cuáles son las Órdenes de Trabajo que actualmente están siendo ejecutadas?
-- Devuelve las OT de la semana en curso que aún no se han cerrado (cumpl_prog NULL o 0).
SELECT
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
ORDER BY inicio_programado
