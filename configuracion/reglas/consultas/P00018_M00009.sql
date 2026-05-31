-- P00018 — Para el sistema X, ¿cuándo se realizó la última mantención?
-- Devuelve la OT ejecutada más reciente (cumpl_prog = 1) para la máquina indicada,
-- en el contexto del/los punto(s) de control que cubre.
SELECT
    punto_nro,
    nombre_punto,
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
  AND ({{ punto }} IS NULL OR punto_nro = {{ punto }})
ORDER BY anio DESC, semana_nro DESC
LIMIT 1
