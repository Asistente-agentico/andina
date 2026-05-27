-- rel_ot_responsable: vincula una orden de trabajo con la persona responsable de ejecutarla.
-- BK compuesta: orden_nro + dni + tipo_dni + dni_pais_emisor.
-- Fuente: bronce_ot_ventilacion (columna 'responsable' que se resuelve a la persona del catálogo HR).
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['orden_nro', 'dni', 'tipo_dni', 'dni_pais_emisor']) }}   AS huella_registro,
    {{ huella_registro(['orden_nro']) }}                                          AS ent_orden_trabajo_hk,
    {{ huella_registro(['dni', 'tipo_dni', 'dni_pais_emisor']) }}                 AS ent_persona_hk,
    orden_nro,
    dni,
    tipo_dni,
    dni_pais_emisor,
    current_timestamp                                                              AS _silver_loaded_at,
    'bronce_ot_ventilacion'                                                        AS _silver_fuente

FROM (
    SELECT DISTINCT
        orden_nro,
        dni,
        tipo_dni,
        dni_pais_emisor
    FROM {{ ref('bronce_ot_ventilacion') }}
    WHERE dni IS NOT NULL
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['orden_nro', 'dni', 'tipo_dni', 'dni_pais_emisor']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
