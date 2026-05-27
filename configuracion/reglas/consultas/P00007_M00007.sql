-- P00007 — ¿Por qué el punto X tiene altos niveles de medición?
-- Identifica la semana del pico del punto y devuelve todas las causas contribuyentes,
-- ordenadas por peso. La causa principal queda primero.
WITH semana_pico AS (
    SELECT punto_hk, semana_hk, planta_hk, semana_nro, anio, concentracion_mg_m3
    FROM {{ mart('M00007') }}
    WHERE punto_nro = {{ punto_nro }}
      AND concentracion_mg_m3 >= 2.5
    ORDER BY concentracion_mg_m3 DESC
    LIMIT 1
)
SELECT
    cr.tipo_causa,
    cr.causa_descripcion,
    cr.estado_valor,
    cr.severidad,
    cr.problema_raiz_nombre,
    cr.familia_causa,
    cr.tipo_equipo_recomendado,
    cr.peso_causa,
    cr.es_causa_principal
FROM {{ mart('M00007') }} cr
JOIN semana_pico sp
     ON cr.punto_hk  = sp.punto_hk
    AND cr.semana_hk = sp.semana_hk
ORDER BY cr.es_causa_principal DESC, cr.peso_causa DESC
