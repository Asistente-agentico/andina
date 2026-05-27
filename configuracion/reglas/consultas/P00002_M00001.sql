-- P00002 — ¿Dónde está el punto de medición más bajo esta semana?
-- "Esta semana" = última semana con mediciones registradas en el datamart.
WITH semana_vigente AS (
    SELECT MAX(anio * 100 + semana_nro) AS clave
    FROM {{ mart('M00001') }}
    WHERE estado = 'medido'
)
SELECT
    planta_canon,
    punto_nro,
    nombre_punto,
    maquina_gen_nombre,
    anio,
    semana_nro,
    fecha_medicion,
    concentracion_mg_m3,
    estado,
    ambito
FROM {{ mart('M00001') }}
WHERE estado = 'medido'
  AND concentracion_mg_m3 > 0
  AND (anio * 100 + semana_nro) = (SELECT clave FROM semana_vigente)
ORDER BY concentracion_mg_m3 ASC
LIMIT 1
