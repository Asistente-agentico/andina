-- ent_planta: una fila por área de planta (BK: planta)
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='merge',
        tags=['capa:silver', 'dominio:minera_prueba']
    )
}}

SELECT
    {{ huella_registro(['planta']) }}   AS huella_registro,
    planta,
    current_timestamp                   AS _silver_loaded_at,
    'bronce_mediciones'                 AS _silver_fuente

FROM (SELECT DISTINCT planta FROM {{ ref('bronce_mediciones') }}) t

{% if is_incremental() %}
WHERE {{ huella_registro(['planta']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
