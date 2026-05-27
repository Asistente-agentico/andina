-- rel_condicion_observada: vincula una condición observada con un punto de medición,
-- un tipo de condición y la semana en que se registró.
-- BK compuesta: punto_nro + condicion_codigo + anio + semana_nro.
-- Fuente: seed condiciones_observadas (registro semanal de condiciones por punto del modelo causal V1).
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['punto_nro', 'condicion_codigo', 'anio', 'semana_nro']) }}   AS huella_registro,
    {{ huella_registro(['punto_nro']) }}                                              AS ent_punto_medicion_hk,
    {{ huella_registro(['condicion_codigo']) }}                                       AS ent_condicion_tipo_hk,
    {{ huella_registro(['anio', 'semana_nro']) }}                                     AS ent_semana_hk,
    punto_nro,
    condicion_codigo,
    anio,
    semana_nro,
    current_timestamp                                                                  AS _silver_loaded_at,
    'semillas.condiciones_observadas'                                                  AS _silver_fuente

FROM (
    SELECT DISTINCT
        punto_nro,
        condicion_codigo,
        anio,
        semana_nro
    FROM {{ ref('condiciones_observadas') }}
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['punto_nro', 'condicion_codigo', 'anio', 'semana_nro']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
