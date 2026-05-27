-- ent_planta: una fila por planta canónica de Codelco Andina.
-- BK: planta_canon (nombre canónico estándar de la planta).
-- Fuente: bronce_mediciones (las 9 áreas medidas) + bronce_ot_ventilacion (las 4 hojas del Programa).
-- 7 plantas canónicas: Prechancado, Chancado Sec/Terc, Chancado Terc/Cuat, Molienda SAG,
-- Nodo 3500, CDM Linea 1, CDM Linea 2.
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['planta_canon']) }}    AS huella_registro,
    planta_canon,
    current_timestamp                            AS _silver_loaded_at,
    'bronce_mediciones+bronce_ot_ventilacion'    AS _silver_fuente

FROM (
    SELECT DISTINCT planta_canon FROM {{ ref('bronce_mediciones') }}
    UNION
    SELECT DISTINCT planta_canon FROM {{ ref('bronce_ot_ventilacion') }}
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['planta_canon']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
