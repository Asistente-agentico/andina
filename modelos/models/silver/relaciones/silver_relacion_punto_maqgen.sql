-- rel_punto_maqgen: vincula un punto de medición con la máquina generadora de polvo
-- que está midiendo. Relación 1:1 — cada punto mide a una sola máquina generadora.
-- BK compuesta: punto_nro + maquina_gen_codigo.
-- Fuente: bronce_mediciones (se infiere desde el nombre del punto y la máquina asociada).
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['punto_nro', 'maquina_gen_codigo']) }}    AS huella_registro,
    {{ huella_registro(['punto_nro']) }}                           AS ent_punto_medicion_hk,
    {{ huella_registro(['maquina_gen_codigo']) }}                  AS ent_maquina_generadora_hk,
    punto_nro,
    maquina_gen_codigo,
    current_timestamp                                                AS _silver_loaded_at,
    'bronce_mediciones'                                              AS _silver_fuente

FROM (
    SELECT DISTINCT
        punto_nro,
        maquina_gen_codigo
    FROM {{ ref('bronce_mediciones') }}
    WHERE maquina_gen_codigo IS NOT NULL
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['punto_nro', 'maquina_gen_codigo']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
