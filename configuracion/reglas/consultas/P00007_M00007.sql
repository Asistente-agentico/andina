-- P00007 — ¿Por qué el punto X tiene altos niveles de medición?
-- Identifica la semana del pico del punto y devuelve todas las causas contribuyentes,
-- ordenadas por peso. La causa principal queda primero.
WITH semana_pico AS (
    SELECT punto_nro, anio, semana_nro, concentracion_mg_m3
    FROM {{ mart('M00007') }}
    WHERE punto_nro = {{ punto_nro }}
      AND concentracion_mg_m3 >= 2.5
    ORDER BY concentracion_mg_m3 DESC
    LIMIT 1
)
SELECT
    cr.punto_nro,
    cr.anio,
    cr.semana_nro,
    cr.tipo_causa,
    cr.causa_descripcion,
    cr.condicion_codigo,
    cr.condicion_nombre,
    cr.severidad,
    cr.problema_raiz_nombre,
    cr.familia_causa,
    cr.ot_relacionada,
    cr.peso_causa,
    cr.es_causa_principal
FROM {{ mart('M00007') }} cr
JOIN semana_pico sp
     ON cr.punto_nro  = sp.punto_nro
    AND cr.anio       = sp.anio
    AND cr.semana_nro = sp.semana_nro
ORDER BY cr.es_causa_principal DESC, cr.peso_causa DESC
