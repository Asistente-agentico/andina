-- det_problema_raiz: atributos descriptivos del problema raíz del modelo causal.
-- Atributos: nombre del problema, familia causal (A/B/C), tipo de intervención recomendada.
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
        problema_raiz_codigo,
        problema_raiz_nombre,
        familia_causa,
        tipo_intervencion
    FROM {{ ref('problemas_raiz') }}
),

con_hash AS (
    SELECT
        {{ huella_registro(['problema_raiz_codigo']) }}                                          AS huella_registro,
        {{ huella_contenido(['problema_raiz_nombre', 'familia_causa', 'tipo_intervencion']) }}   AS _huella_contenido,
        problema_raiz_nombre,
        familia_causa,
        tipo_intervencion,
        current_timestamp                AS valid_from,
        NULL::TIMESTAMP                  AS valid_to,
        1                                AS version_seq,
        'semillas.problemas_raiz'        AS _silver_fuente
    FROM src
)

SELECT * FROM con_hash

{% if is_incremental() %}
WHERE _huella_contenido NOT IN (
    SELECT _huella_contenido FROM {{ this }}
    WHERE huella_registro IN (SELECT huella_registro FROM con_hash)
)
{% endif %}
