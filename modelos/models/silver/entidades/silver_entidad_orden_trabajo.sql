-- ent_orden_trabajo: una fila por orden de trabajo del Programa de ventilación.
-- BK: orden_nro (número único de la OT en el sistema SAP-PM del cliente).
-- Fuente: bronce_ot_ventilacion (union de las 4 hojas del Programa Semana 21 2026).
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['orden_nro']) }}    AS huella_registro,
    orden_nro,
    current_timestamp                        AS _silver_loaded_at,
    'bronce_ot_ventilacion'                  AS _silver_fuente

FROM (
    SELECT DISTINCT
        orden_nro
    FROM {{ ref('bronce_ot_ventilacion') }}
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['orden_nro']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
