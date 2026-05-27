-- ent_persona: una fila por persona del catálogo (BK: dni + tipo_dni + dni_pais_emisor)
-- Fuente: seed personas_alias (catálogo de personas con RUNs sintéticos para este caso de prueba).
-- En producción: reemplazar por landing desde sistema HR/ERP del cliente.
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['dni', 'tipo_dni', 'dni_pais_emisor']) }}   AS huella_registro,
    dni,
    tipo_dni,
    dni_pais_emisor,
    current_timestamp                                               AS _silver_loaded_at,
    'semillas.personas_alias'                                       AS _silver_fuente

FROM (
    SELECT DISTINCT
        dni,
        tipo_dni,
        dni_pais_emisor
    FROM {{ ref('personas_alias') }}
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['dni', 'tipo_dni', 'dni_pais_emisor']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
