-- rel_punto_componente: vincula un punto de medición con el componente estructural
-- (chute / pieza de correa) que está midiendo. Permite que dos puntos sobre la misma
-- correa apunten a chutes distintos (ej. puntos 60 y 61 de CDM Línea 1).
-- BK compuesta: punto_nro + componente_codigo (código completo: maqgen_parte).
-- Fuente: bronce_mediciones (enriquecido vía seed puntos_catalogo).
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['punto_nro', 'componente_codigo_full']) }}    AS huella_registro,
    {{ huella_registro(['punto_nro']) }}                               AS ent_punto_medicion_hk,
    {{ huella_registro(['componente_codigo_full']) }}                  AS ent_componente_estructural_hk,
    punto_nro,
    componente_codigo_full                                              AS componente_codigo,
    current_timestamp                                                   AS _silver_loaded_at,
    'bronce_mediciones'                                                 AS _silver_fuente

FROM (
    SELECT DISTINCT
        punto_nro,
        componente_codigo_full
    FROM {{ ref('bronce_mediciones') }}
    WHERE componente_codigo_full IS NOT NULL
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['punto_nro', 'componente_codigo_full']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
