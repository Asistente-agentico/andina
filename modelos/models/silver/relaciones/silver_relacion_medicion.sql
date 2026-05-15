-- rel_medicion: vincula un punto de medición con una sesión semanal
-- BK compuesta: ent_punto_medicion + ent_sesion_medicion
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='merge',
        tags=['capa:silver', 'dominio:minera_prueba']
    )
}}

SELECT
    {{ huella_registro(['planta', 'punto_evaluacion', 'anio', 'semana']) }}     AS huella_registro,
    {{ huella_registro(['planta', 'punto_evaluacion']) }}                        AS ent_punto_medicion_hk,
    {{ huella_registro(['planta', 'anio', 'semana']) }}                          AS ent_sesion_medicion_hk,
    planta,
    punto_evaluacion,
    anio,
    semana,
    current_timestamp                                                            AS _silver_loaded_at,
    'bronce_mediciones'                                                          AS _silver_fuente

FROM (
    SELECT DISTINCT planta, punto_evaluacion, anio, semana
    FROM {{ ref('bronce_mediciones') }}
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['planta', 'punto_evaluacion', 'anio', 'semana']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
