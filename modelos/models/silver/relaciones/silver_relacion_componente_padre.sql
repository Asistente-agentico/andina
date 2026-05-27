-- rel_componente_padre: vincula un componente estructural hijo con su componente padre.
-- Modela la jerarquía de 2 niveles del modelo causal V1 (familia A):
--   nivel 0 = chute, cinta, raspadores (sin padre)
--   nivel 1 = partes del chute (faldones, sello de goma, deflectores, etc.)
-- BK compuesta: componente_hijo + componente_padre. Self-link sobre H_COMPONENTE_ESTRUCTURAL.
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
    {{ huella_registro(['componente_codigo', 'componente_padre_codigo']) }}   AS huella_registro,
    {{ huella_registro(['componente_codigo']) }}                               AS ent_componente_estructural_hijo_hk,
    {{ huella_registro(['componente_padre_codigo']) }}                         AS ent_componente_estructural_padre_hk,
    componente_codigo,
    componente_padre_codigo,
    current_timestamp                                                           AS _silver_loaded_at,
    'semillas.componentes_estructurales'                                        AS _silver_fuente

FROM (
    SELECT DISTINCT
        componente_codigo,
        componente_padre_codigo
    FROM {{ ref('componentes_estructurales') }}
    WHERE componente_padre_codigo IS NOT NULL
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['componente_codigo', 'componente_padre_codigo']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
