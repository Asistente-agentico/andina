-- ent_tipo_equipo_ctrl: una fila por tipo de equipo de control de polvo.
-- BK: tipo_equipo_codigo (HDP, CDP, EPZ, VEX, VIN, PVA, PVM, PTV, PIN, DAM).
-- Fuente: seed tipos_equipo_ctrl (catálogo estático del dominio de ventilación minera).
-- Cada tipo pertenece a una familia: SVE (renovacion_aire) o SCP (abatidor_polvo).
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['tipo_equipo_codigo']) }}    AS huella_registro,
    tipo_equipo_codigo,
    current_timestamp                                  AS _silver_loaded_at,
    'semillas.tipos_equipo_ctrl'                       AS _silver_fuente

FROM (
    SELECT DISTINCT
        tipo_equipo_codigo
    FROM {{ ref('tipos_equipo_ctrl') }}
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['tipo_equipo_codigo']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
