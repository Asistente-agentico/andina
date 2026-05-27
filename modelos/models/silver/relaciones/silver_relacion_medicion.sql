-- rel_medicion: vincula un punto de medición con una semana ISO.
-- Es la unidad atómica del hecho de medición: cada combinación punto + semana = 1 medición.
-- BK compuesta: punto_nro + anio + semana_nro.
-- Fuente: bronce_mediciones (todas las celdas del unpivot, incluso las que tienen estado 'no_medido').
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['punto_nro', 'anio', 'semana_nro']) }}    AS huella_registro,
    {{ huella_registro(['punto_nro']) }}                           AS ent_punto_medicion_hk,
    {{ huella_registro(['anio', 'semana_nro']) }}                  AS ent_semana_hk,
    punto_nro,
    anio,
    semana_nro,
    current_timestamp                                                AS _silver_loaded_at,
    'bronce_mediciones'                                              AS _silver_fuente

FROM (
    SELECT DISTINCT
        punto_nro,
        anio,
        semana_nro
    FROM {{ ref('bronce_mediciones') }}
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['punto_nro', 'anio', 'semana_nro']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
