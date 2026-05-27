-- ent_maquina_control_polvo: una fila por máquina de control de polvo del catálogo.
-- BK: ubicacion_tecnica (código ANCO-PLANTA-SECTOR-FAMILIA-TIPO-EQUIPO, único por máquina).
-- Fuente: bronce_equipos_ventilacion (deriva tipo y familia desde el código).
-- Familia: renovacion_aire (SVE) o abatidor_polvo (SCP).
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['ubicacion_tecnica']) }}    AS huella_registro,
    ubicacion_tecnica,
    current_timestamp                                AS _silver_loaded_at,
    'bronce_equipos_ventilacion'                     AS _silver_fuente

FROM (
    SELECT DISTINCT
        ubicacion_tecnica
    FROM {{ ref('bronce_equipos_ventilacion') }}
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['ubicacion_tecnica']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
