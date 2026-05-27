-- ent_condicion_tipo: una fila por tipo de condición observada en un punto.
-- BK: condicion_codigo (código único del tipo de condición).
-- Fuente: seed condiciones_tipo (catálogo del modelo causal V1).
-- Ejemplos: humectacion_baja, ventilacion_insuficiente, aseo_deficiente, polvo_acumulado, etc.
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['condicion_codigo']) }}    AS huella_registro,
    condicion_codigo,
    current_timestamp                               AS _silver_loaded_at,
    'semillas.condiciones_tipo'                     AS _silver_fuente

FROM (
    SELECT DISTINCT
        condicion_codigo
    FROM {{ ref('condiciones_tipo') }}
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['condicion_codigo']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
