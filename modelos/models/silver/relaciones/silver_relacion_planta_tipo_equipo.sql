-- rel_planta_tipo_equipo: vincula una planta con los tipos de equipo de control de polvo
-- que tiene desplegados. Representa la cobertura de control de polvo por planta.
-- BK compuesta: planta_canon + tipo_equipo_codigo.
-- Fuente: bronce_equipos_ventilacion (deriva planta y tipo desde el código del catálogo DAND).
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['planta_canon', 'tipo_equipo_codigo']) }}    AS huella_registro,
    {{ huella_registro(['planta_canon']) }}                           AS ent_planta_hk,
    {{ huella_registro(['tipo_equipo_codigo']) }}                     AS ent_tipo_equipo_ctrl_hk,
    planta_canon,
    tipo_equipo_codigo,
    current_timestamp                                                  AS _silver_loaded_at,
    'bronce_equipos_ventilacion'                                       AS _silver_fuente

FROM (
    SELECT DISTINCT
        planta_canon,
        tipo_equipo_codigo
    FROM {{ ref('bronce_equipos_ventilacion') }}
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['planta_canon', 'tipo_equipo_codigo']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
