-- det_persona: atributos descriptivos de la persona del catálogo (una fila por persona).
-- El seed personas_alias tiene varias filas por persona (un alias por fila); aquí se deduplica
-- por BK (dni + tipo_dni + dni_pais_emisor). El mapeo alias→persona vive en el link
-- rel_medicion_persona, no en este detalle.
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
    SELECT DISTINCT
        dni,
        tipo_dni,
        dni_pais_emisor,
        nombre_completo,
        tipo_persona
    FROM {{ ref('personas_alias') }}
),

con_hash AS (
    SELECT
        {{ huella_registro(['dni', 'tipo_dni', 'dni_pais_emisor']) }}       AS huella_registro,
        {{ huella_contenido(['nombre_completo', 'tipo_persona']) }}         AS _huella_contenido,
        nombre_completo,
        tipo_persona,
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
