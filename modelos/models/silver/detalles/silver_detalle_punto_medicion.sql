-- det_punto_medicion: atributos descriptivos del punto de medición.
-- Atributos: nombre del punto, descripción, tipo (real / sintético).
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
        punto_nro,
        nombre_punto,
        descripcion_punto,
        tipo_punto
    FROM {{ ref('bronce_mediciones') }}
),

con_hash AS (
    SELECT
        {{ huella_registro(['punto_nro']) }}                                            AS huella_registro,
        {{ huella_contenido(['nombre_punto', 'descripcion_punto', 'tipo_punto']) }}      AS _huella_contenido,
        nombre_punto,
        descripcion_punto,
        tipo_punto,
        current_timestamp                AS valid_from,
        NULL::TIMESTAMP                  AS valid_to,
        1                                AS version_seq,
        'bronce_mediciones'              AS _silver_fuente
    FROM src
)

SELECT * FROM con_hash

{% if is_incremental() %}
WHERE _huella_contenido NOT IN (
    SELECT _huella_contenido FROM {{ this }}
    WHERE huella_registro IN (SELECT huella_registro FROM con_hash)
)
{% endif %}
