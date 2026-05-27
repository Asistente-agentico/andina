-- det_ot_descr: atributos descriptivos de la orden de trabajo.
-- Atributos: texto breve, denominación de ubicación técnica, clase de orden, clase actividad PM.
-- Historicidad: append-only, unique_key = (huella_registro, valid_from).
{{
    config(
        materialized='incremental',
        unique_key=['huella_registro', 'valid_from'],
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

WITH src AS (
    SELECT
        orden_nro,
        ot_texto_breve,
        denom_ubic_tecnica,
        clase_orden,
        clase_actividad_pm
    FROM {{ ref('bronce_ot_ventilacion') }}
),

con_hash AS (
    SELECT
        {{ huella_registro(['orden_nro']) }}                                                                       AS huella_registro,
        {{ huella_contenido(['ot_texto_breve', 'denom_ubic_tecnica', 'clase_orden', 'clase_actividad_pm']) }}      AS _huella_contenido,
        ot_texto_breve,
        denom_ubic_tecnica,
        clase_orden,
        clase_actividad_pm,
        current_timestamp                AS valid_from,
        NULL::TIMESTAMP                  AS valid_to,
        1                                AS version_seq,
        'bronce_ot_ventilacion'          AS _silver_fuente
    FROM src
)

SELECT * FROM con_hash

{% if is_incremental() %}
WHERE _huella_contenido NOT IN (
    SELECT _huella_contenido FROM {{ this }}
    WHERE huella_registro IN (SELECT huella_registro FROM con_hash)
)
{% endif %}
