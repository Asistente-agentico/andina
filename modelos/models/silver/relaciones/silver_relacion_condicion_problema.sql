-- rel_condicion_problema: vincula un tipo de condición con su problema raíz asociado.
-- Modela la cadena causal: condición observada → problema raíz que la explica.
-- BK compuesta: condicion_codigo + problema_raiz_codigo.
-- Fuente: seed condiciones_problema (mapeo del modelo causal V1).
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['condicion_codigo', 'problema_raiz_codigo']) }}   AS huella_registro,
    {{ huella_registro(['condicion_codigo']) }}                            AS ent_condicion_tipo_hk,
    {{ huella_registro(['problema_raiz_codigo']) }}                        AS ent_problema_raiz_hk,
    condicion_codigo,
    problema_raiz_codigo,
    current_timestamp                                                       AS _silver_loaded_at,
    'semillas.condiciones_problema'                                         AS _silver_fuente

FROM (
    SELECT DISTINCT
        condicion_codigo,
        problema_raiz_codigo
    FROM {{ ref('condiciones_problema') }}
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['condicion_codigo', 'problema_raiz_codigo']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
