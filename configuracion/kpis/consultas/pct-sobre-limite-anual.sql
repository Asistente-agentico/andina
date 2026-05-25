SELECT
    planta,
    anio,
    pct_sobre_limite        AS valor_actual,
    registros_sobre_limite,
    total_registros,
    limite_interno_mg_m3
FROM {{ modelo_oro }}
WHERE 1=1
{{ where_gobernanza }}
ORDER BY planta, anio DESC
