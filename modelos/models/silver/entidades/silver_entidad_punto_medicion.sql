-- ent_punto_medicion: una fila por punto de medición de polvo respirable.
-- BK: punto_nro (número único del punto, asignado por el equipo de higiene industrial).
-- Fuente: bronce_mediciones (los 14 puntos reales + 23 sintéticos del Resumen).
-- Cada punto está anclado a una planta y mide una máquina generadora específica (1:1).
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['punto_nro']) }}    AS huella_registro,
    punto_nro,
    current_timestamp                        AS _silver_loaded_at,
    'bronce_mediciones'                      AS _silver_fuente

FROM (
    SELECT DISTINCT
        punto_nro
    FROM {{ ref('bronce_mediciones') }}
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['punto_nro']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
