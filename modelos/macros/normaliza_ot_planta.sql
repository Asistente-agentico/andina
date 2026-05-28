{#-
    normaliza_ot_planta — Normaliza una hoja del Programa de Ventilación al
    formato común del bronce de OT (Órdenes de Trabajo).

    Estructura de entrada (snapshot de una hoja del Programa):
      Columnas típicas: Denom.ubic.técnica, Orden, Clase de orden,
      Clase actividad PM, Grupo hojas ruta, Texto breve,
      Ubicación técnica, Pto.tbjo.responsable, Status de sistema,
      Fecha liber.real, Fecha inicio extrema, Inicio programado

    Hard rules aplicadas (DV Guru):
      - cast a TEXT + trim + UPPER en columnas que serán BK (Orden, Ubicación técnica)
      - NULL → -1 (zero-key) en BK
      - fechas a TIMESTAMP, formato ISO 8601 + Z en salida texto
      - planta_canon resuelto por parámetro (la hoja origen determina la planta)

    Parámetros:
      snapshot_ref      — ref() al snapshot de la hoja del Programa
                          (eg. ref('snap_programa_molienda'))
      planta_canonical  — nombre canónico según domain.yaml
                          (eg. 'Molienda SAG', 'Pre-Chancado', 'CDM')
-#}
{% macro normaliza_ot_planta(snapshot_ref, planta_canonical) %}
SELECT
    -- BK normalizadas (cast text + trim + UPPER + zero-key)
    COALESCE(NULLIF(UPPER(TRIM(CAST("Orden" AS VARCHAR))), ''), '-1')                    AS orden_nro,
    COALESCE(NULLIF(UPPER(TRIM(CAST("Ubicación técnica" AS VARCHAR))), ''), '-1')        AS ubicacion_tecnica,

    -- Atributos descriptivos (trim, sin UPPER para preservar legibilidad)
    NULLIF(TRIM(CAST("Denom.ubic.técnica" AS VARCHAR)), '')                              AS equipo_denom,
    NULLIF(TRIM(CAST("Clase de orden" AS VARCHAR)), '')                                  AS clase_orden,
    NULLIF(TRIM(CAST("Clase actividad PM" AS VARCHAR)), '')                              AS clase_actividad_pm,
    NULLIF(TRIM(CAST("Grupo hojas ruta" AS VARCHAR)), '')                                AS grupo_hojas_ruta,
    NULLIF(TRIM(CAST("Texto breve" AS VARCHAR)), '')                                     AS ot_texto_breve,
    NULLIF(TRIM(CAST("Pto.tbjo.responsable" AS VARCHAR)), '')                            AS pto_trabajo_responsable,
    NULLIF(TRIM(CAST("Status de sistema" AS VARCHAR)), '')                               AS status_sistema,

    -- Fechas: cast a TIMESTAMP y luego a texto ISO 8601 + Z
    {{ local_a_utc('"Fecha liber.real"') }}                                              AS fecha_liberacion_real,
    {{ local_a_utc('"Fecha inicio extrema"') }}                                          AS fecha_inicio_extrema,
    {{ local_a_utc('"Inicio programado"') }}                                             AS inicio_programado,

    -- planta resuelto por parámetro (la hoja origen indica la planta)
    '{{ planta_canonical }}'                                                             AS planta_canon,

    -- Auditoría bronce
    '{{ snapshot_ref }}'                                                                 AS _bronce_fuente,
    {{ utc_ahora() }}                                                                    AS _bronce_loaded_at

FROM {{ snapshot_ref }}
WHERE dbt_valid_to IS NULL
  AND "Orden" IS NOT NULL
  AND TRIM(CAST("Orden" AS VARCHAR)) != ''
{% endmacro %}
