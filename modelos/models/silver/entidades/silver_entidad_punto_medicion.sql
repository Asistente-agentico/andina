-- ent_punto_medicion: una fila por punto de medición por planta (BK: planta + punto_evaluacion)
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='merge',
        tags=['capa:silver', 'dominio:minera_prueba']
    )
}}

SELECT
    {{ huella_registro(['planta', 'punto_evaluacion']) }}    AS huella_registro,
    planta,
    punto_evaluacion,
    current_timestamp                                        AS _silver_loaded_at,
    'bronce_mediciones'                                      AS _silver_fuente

FROM (SELECT DISTINCT planta, punto_evaluacion FROM {{ ref('bronce_mediciones') }}) t

{% if is_incremental() %}
WHERE {{ huella_registro(['planta', 'punto_evaluacion']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
