-- ent_maquina_generadora: una fila por máquina generadora de polvo
-- (correa, harnero, alimentador, chancador, etc. — la fuente del polvo).
-- BK: maquina_gen_codigo (código único de la máquina dentro de su planta).
-- Fuente: bronce_mediciones (se infiere desde el nombre del punto de medición).
-- Relación 1:1 con H_PUNTO_MEDICION (cada punto mide a una sola máquina).
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['maquina_gen_codigo']) }}    AS huella_registro,
    maquina_gen_codigo,
    current_timestamp                                 AS _silver_loaded_at,
    'bronce_mediciones'                               AS _silver_fuente

FROM (
    SELECT DISTINCT
        maquina_gen_codigo
    FROM {{ ref('bronce_mediciones') }}
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['maquina_gen_codigo']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
