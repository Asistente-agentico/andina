SELECT
    planta,
    punto_evaluacion,
    concentracion_mg_m3     AS valor_actual,
    estado_limite,
    limite_interno_mg_m3,
    anio,
    semana
FROM {{ modelo_oro }}
WHERE 1=1
{{ where_gobernanza }}
ORDER BY concentracion_mg_m3 DESC
