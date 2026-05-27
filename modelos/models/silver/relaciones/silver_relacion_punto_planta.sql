-- rel_punto_planta: vincula un punto de medición con su planta canónica.
-- Relación N:1 — cada punto pertenece a una sola planta.
-- BK compuesta: punto_nro + planta_canon.
-- Fuente: bronce_mediciones (la planta se deriva de la hoja origen).
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['punto_nro', 'planta_canon']) }}    AS huella_registro,
    {{ huella_registro(['punto_nro']) }}                     AS ent_punto_medicion_hk,
    {{ huella_registro(['planta_canon']) }}                  AS ent_planta_hk,
    punto_nro,
    planta_canon,
    current_timestamp                                          AS _silver_loaded_at,
    'bronce_mediciones'                                        AS _silver_fuente

FROM (
    SELECT DISTINCT
        punto_nro,
        planta_canon
    FROM {{ ref('bronce_mediciones') }}
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['punto_nro', 'planta_canon']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
