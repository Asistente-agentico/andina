SELECT
    planta_canon,
    anio,
    pendiente_mg_m3_por_semana,
    r2,
    tendencia,
    n_puntos,
    promedio_planta_mg_m3
FROM {{ modelo_oro }}
WHERE 1=1
{{ where_gobernanza }}
{% if anio %}AND anio = {{ anio }}{% endif %}
ORDER BY pendiente_mg_m3_por_semana DESC, planta_canon
