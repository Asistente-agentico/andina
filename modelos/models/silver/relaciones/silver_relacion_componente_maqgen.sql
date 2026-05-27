-- rel_componente_maqgen: vincula un componente estructural con la máquina generadora
-- a la que pertenece (típicamente: chutes / partes / cinta / raspadores asociados a una correa).
-- BK compuesta: ent_componente_estructural + ent_maquina_generadora.
-- Fuente: seed componentes_estructurales (catálogo del modelo causal V1).
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['componente_codigo', 'maquina_gen_codigo']) }}    AS huella_registro,
    {{ huella_registro(['componente_codigo']) }}                           AS ent_componente_estructural_hk,
    {{ huella_registro(['maquina_gen_codigo']) }}                          AS ent_maquina_generadora_hk,
    componente_codigo,
    maquina_gen_codigo,
    current_timestamp                                                       AS _silver_loaded_at,
    'semillas.componentes_estructurales'                                    AS _silver_fuente

FROM (
    SELECT DISTINCT
        componente_codigo,
        maquina_gen_codigo
    FROM {{ ref('componentes_estructurales') }}
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['componente_codigo', 'maquina_gen_codigo']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
