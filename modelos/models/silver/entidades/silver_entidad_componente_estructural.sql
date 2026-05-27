-- ent_componente_estructural: una fila por componente estructural de correa
-- (chutes, partes del chute, cinta, raspadores). Jerarquía de 2 niveles.
-- BK: componente_codigo (código único del componente dentro de su máquina padre).
-- Fuente: seed componentes_estructurales (catálogo del modelo causal V1, familia A).
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['componente_codigo']) }}    AS huella_registro,
    componente_codigo,
    current_timestamp                                AS _silver_loaded_at,
    'semillas.componentes_estructurales'             AS _silver_fuente

FROM (
    SELECT DISTINCT
        componente_codigo
    FROM {{ ref('componentes_estructurales') }}
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['componente_codigo']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
