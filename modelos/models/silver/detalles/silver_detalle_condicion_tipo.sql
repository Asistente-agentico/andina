-- det_condicion_tipo: atributos descriptivos del tipo de condición observada.
-- Atributos: nombre descriptivo, familia causal (A/B/C), peso causal por defecto.
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
        condicion_codigo,
        nombre              AS condicion_nombre,
        peso_causa_default
    FROM {{ ref('condiciones_tipo') }}
),

con_hash AS (
    SELECT
        {{ huella_registro(['condicion_codigo']) }}                                    AS huella_registro,
        {{ huella_contenido(['condicion_nombre', 'peso_causa_default']) }} AS _huella_contenido,
        condicion_nombre,
        peso_causa_default,
        current_timestamp                AS valid_from,
        NULL::TIMESTAMP                  AS valid_to,
        1                                AS version_seq,
        'semillas.condiciones_tipo'      AS _silver_fuente
    FROM src
)

SELECT * FROM con_hash

{% if is_incremental() %}
WHERE _huella_contenido NOT IN (
    SELECT _huella_contenido FROM {{ this }}
    WHERE huella_registro IN (SELECT huella_registro FROM con_hash)
)
{% endif %}
