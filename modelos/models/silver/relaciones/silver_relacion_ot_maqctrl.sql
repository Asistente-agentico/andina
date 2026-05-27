-- rel_ot_maqctrl: vincula una orden de trabajo con la máquina de control de polvo intervenida.
-- BK compuesta: orden_nro + ubicacion_tecnica (clave de la máquina control).
-- Fuente: bronce_ot_ventilacion (cada OT del Programa de ventilación apunta a una ubicación técnica).
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['orden_nro', 'ubicacion_tecnica']) }}   AS huella_registro,
    {{ huella_registro(['orden_nro']) }}                         AS ent_orden_trabajo_hk,
    {{ huella_registro(['ubicacion_tecnica']) }}                 AS ent_maquina_control_polvo_hk,
    orden_nro,
    ubicacion_tecnica,
    current_timestamp                                            AS _silver_loaded_at,
    'bronce_ot_ventilacion'                                      AS _silver_fuente

FROM (
    SELECT DISTINCT
        orden_nro,
        ubicacion_tecnica
    FROM {{ ref('bronce_ot_ventilacion') }}
    WHERE ubicacion_tecnica IS NOT NULL
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['orden_nro', 'ubicacion_tecnica']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
