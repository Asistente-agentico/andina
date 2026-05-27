-- ent_semana: una fila por semana ISO (BK: anio + semana_nro).
-- BK incluye anio para evitar colisión: el CSV tiene semanas 1-52 de 2025 y 1-19 de 2026.
-- Fuente: bronce_mediciones (semanas medidas) + bronce_ot_ventilacion (semanas con OT).
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['anio', 'semana_nro']) }}    AS huella_registro,
    anio,
    semana_nro,
    current_timestamp                                  AS _silver_loaded_at,
    'bronce_mediciones+bronce_ot_ventilacion'          AS _silver_fuente

FROM (
    SELECT DISTINCT anio, semana_nro FROM {{ ref('bronce_mediciones') }}
    UNION
    SELECT DISTINCT anio, semana_nro FROM {{ ref('bronce_ot_ventilacion') }}
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['anio', 'semana_nro']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
