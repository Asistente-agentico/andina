-- det_planta: atributos descriptivos de la planta canónica.
-- Atributos: nombre canónico legible, área (chancado / molienda / cdm / nodo), sector.
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
        planta_canon,
        nombre_planta,
        area,
        sector
    FROM {{ ref('plantas_descripcion') }}
),

con_hash AS (
    SELECT
        {{ huella_registro(['planta_canon']) }}                                AS huella_registro,
        {{ huella_contenido(['nombre_planta', 'area', 'sector']) }}            AS _huella_contenido,
        nombre_planta,
        area,
        sector,
        current_timestamp                AS valid_from,
        NULL::TIMESTAMP                  AS valid_to,
        1                                AS version_seq,
        'semillas.plantas_descripcion'   AS _silver_fuente
    FROM src
)

SELECT * FROM con_hash

{% if is_incremental() %}
WHERE _huella_contenido NOT IN (
    SELECT _huella_contenido FROM {{ this }}
    WHERE huella_registro IN (SELECT huella_registro FROM con_hash)
)
{% endif %}
