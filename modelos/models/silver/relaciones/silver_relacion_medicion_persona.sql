-- rel_medicion_persona: vincula un evento de medición con las personas presentes
-- Genera 2 filas por medición: una para operador, otra para técnico.
-- BK: rel_medicion + ent_persona + rol
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='merge',
        tags=['capa:silver', 'dominio:minera_prueba']
    )
}}

WITH bronce AS (
    SELECT
        planta,
        punto_evaluacion,
        anio,
        semana,
        operador_alias,
        tecnico_alias
    FROM {{ ref('bronce_mediciones') }}
    WHERE operador_alias IS NOT NULL OR tecnico_alias IS NOT NULL
),

personas AS (
    SELECT alias_fuente, dni, tipo_dni, dni_pais_emisor
    FROM {{ ref('personas_alias') }}
),

operadores AS (
    SELECT
        b.planta,
        b.punto_evaluacion,
        b.anio,
        b.semana,
        'operador'      AS rol,
        p.dni,
        p.tipo_dni,
        p.dni_pais_emisor
    FROM bronce b
    JOIN personas p ON trim(b.operador_alias) = p.alias_fuente
    WHERE b.operador_alias IS NOT NULL
),

tecnicos AS (
    SELECT
        b.planta,
        b.punto_evaluacion,
        b.anio,
        b.semana,
        'tecnico'       AS rol,
        p.dni,
        p.tipo_dni,
        p.dni_pais_emisor
    FROM bronce b
    JOIN personas p ON trim(b.tecnico_alias) = p.alias_fuente
    WHERE b.tecnico_alias IS NOT NULL
),

unificado AS (
    SELECT * FROM operadores
    UNION ALL
    SELECT * FROM tecnicos
)

SELECT
    {{ huella_registro(['planta', 'punto_evaluacion', 'anio', 'semana', 'rol', 'dni', 'tipo_dni', 'dni_pais_emisor']) }}    AS huella_registro,
    {{ huella_registro(['planta', 'punto_evaluacion', 'anio', 'semana']) }}                                                  AS rel_medicion_hk,
    {{ huella_registro(['dni', 'tipo_dni', 'dni_pais_emisor']) }}                                                            AS ent_persona_hk,
    planta,
    punto_evaluacion,
    anio,
    semana,
    rol,
    dni,
    current_timestamp                                                                                                        AS _silver_loaded_at,
    'bronce_mediciones'                                                                                                      AS _silver_fuente

FROM (SELECT DISTINCT * FROM unificado) t

{% if is_incremental() %}
WHERE {{ huella_registro(['planta', 'punto_evaluacion', 'anio', 'semana', 'rol', 'dni', 'tipo_dni', 'dni_pais_emisor']) }}
    NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
