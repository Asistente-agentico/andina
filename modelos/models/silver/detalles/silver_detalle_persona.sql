-- det_persona: atributos descriptivos de la persona del catálogo.
-- Atributos: nombre completo, tipo de persona, alias.
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
        dni,
        tipo_dni,
        dni_pais_emisor,
        nombre_completo,
        tipo_persona,
        alias
    FROM {{ ref('personas_alias') }}
),

con_hash AS (
    SELECT
        {{ huella_registro(['dni', 'tipo_dni', 'dni_pais_emisor']) }}                       AS huella_registro,
        {{ huella_contenido(['nombre_completo', 'tipo_persona', 'alias']) }}                AS _huella_contenido,
        nombre_completo,
        tipo_persona,
        alias,
        current_timestamp                AS valid_from,
        NULL::TIMESTAMP                  AS valid_to,
        1                                AS version_seq,
        'semillas.personas_alias'        AS _silver_fuente
    FROM src
)

SELECT * FROM con_hash

{% if is_incremental() %}
WHERE _huella_contenido NOT IN (
    SELECT _huella_contenido FROM {{ this }}
    WHERE huella_registro IN (SELECT huella_registro FROM con_hash)
)
{% endif %}
