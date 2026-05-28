{#-
    parsea_codigo_equipo — Parsea el código de equipo del catálogo DAND
    al formato común del bronce de equipos de ventilación.

    Formato del código (ejemplo): ANCO-CF-CST-SCP-HDP06-MEC
      Tokens separados por "-":
        0: ANCO        → división (Andina, fijo)
        1: CF          → planta (CF=Chancado Fino, MO=Molienda, etc.)
        2: CST         → sector
        3: SCP         → familia (SCP=abatidor de polvo, SVE=renovación aire)
        4: HDP06       → tipo+correlativo (HDP=humectador, EPZ=presurizador, etc.)
        5: MEC         → especialidad (opcional, ej. MEC=mecánico)

    Hard rules aplicadas (DV Guru):
      - cast a TEXT + trim + UPPER en código completo y tokens
      - NULL → -1 (zero-key) en BK
      - planta_canon resuelto por mapeo según token planta
      - familia derivada: SCP → abatidor_polvo, SVE → renovacion_aire

    Parámetros:
      snapshot_ref — ref() al snapshot del catálogo DAND
                     (eg. ref('snap_equipos_ventilacion_catalogo'))
-#}
{% macro parsea_codigo_equipo(snapshot_ref) %}
WITH src AS (
    SELECT *
    FROM {{ snapshot_ref }}
    WHERE dbt_valid_to IS NULL
),

tokens AS (
    SELECT
        codigo_original,
        UPPER(TRIM(CAST(codigo_original AS VARCHAR)))                AS codigo_upper,
        STRING_SPLIT(UPPER(TRIM(CAST(codigo_original AS VARCHAR))), '-') AS partes
    FROM src
    WHERE codigo_original IS NOT NULL
      AND TRIM(CAST(codigo_original AS VARCHAR)) != ''
)

SELECT
    -- BK normalizada (cast text + trim + UPPER + zero-key)
    COALESCE(NULLIF(codigo_upper, ''), '-1')                          AS maquina_ctrl_codigo,

    -- Tokens parseados (con zero-key si falta)
    COALESCE(partes[1], '-1')                                         AS token_division,
    COALESCE(partes[2], '-1')                                         AS token_planta,
    COALESCE(partes[3], '-1')                                         AS token_sector,
    COALESCE(partes[4], '-1')                                         AS token_familia,
    COALESCE(partes[5], '-1')                                         AS token_tipo_correlativo,
    COALESCE(partes[6], '-1')                                         AS token_especialidad,

    -- planta_canon resuelta por mapeo del token planta
    CASE partes[2]
        WHEN 'PC' THEN 'Pre-Chancado'
        WHEN 'CS' THEN 'Chancado 2° y 3°'
        WHEN 'CF' THEN 'Chancado Fino'
        WHEN 'MO' THEN 'Molienda SAG'
        WHEN 'MC' THEN 'Molienda Convencional'
        WHEN 'CDM' THEN 'CDM'
        WHEN 'NO' THEN 'Nodo 3500'
        ELSE 'Sin clasificar'
    END                                                               AS planta_canon,

    -- Familia derivada del token familia
    CASE partes[4]
        WHEN 'SCP' THEN 'abatidor_polvo'
        WHEN 'SVE' THEN 'renovacion_aire'
        ELSE 'otro'
    END                                                               AS familia_equipo,

    -- Tipo de equipo derivado del prefijo (primeros 3 caracteres del token_tipo)
    SUBSTRING(COALESCE(partes[5], ''), 1, 3)                          AS tipo_equipo_codigo,

    -- Auditoría bronce
    '{{ snapshot_ref }}'                                              AS _bronce_fuente,
    {{ utc_ahora() }}                                                 AS _bronce_loaded_at

FROM tokens
{% endmacro %}
