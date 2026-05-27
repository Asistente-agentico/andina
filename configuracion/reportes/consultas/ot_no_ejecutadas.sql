SELECT
    orden_nro,
    ot_texto_breve,
    equipo_denom,
    ubicacion_tecnica,
    tipo_equipo,
    familia,
    planta_canon,
    anio,
    semana_nro,
    inicio_programado,
    motivo_no_ejecucion,
    fecha_reprogramacion
FROM {{ modelo_oro }}
WHERE 1=1
  AND cumpl_prog = 0
{{ where_gobernanza }}
{% if anio %}AND anio = {{ anio }}{% endif %}
{% if semana %}AND semana_nro = {{ semana }}{% endif %}
ORDER BY planta_canon, anio DESC, semana_nro DESC, orden_nro
