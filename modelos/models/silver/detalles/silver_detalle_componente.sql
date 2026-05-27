-- det_componente: atributos descriptivos del componente estructural de correa.
-- Historicidad: append-only, unique_key = (huella_registro, valid_from).
-- Detecta cambios mediante _huella_contenido (hash de atributos descriptivos).
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
        componente_codigo,
        componente_nombre,
        tipo_componente,
        nivel_jerarquia,
        familia_causa
    FROM {{ ref('componentes_estructurales') }}
),

con_hash AS (
    SELECT
        {{ huella_registro(['componente_codigo']) }}                                              AS huella_registro,
        {{ huella_contenido(['componente_nombre', 'tipo_componente', 'nivel_jerarquia', 'familia_causa']) }} AS _huella_contenido,
        componente_nombre,
        tipo_componente,
        nivel_jerarquia,
        familia_causa,
        current_timestamp                AS valid_from,
        NULL::TIMESTAMP                  AS valid_to,
        1                                AS version_seq,
        'semillas.componentes_estructurales' AS _silver_fuente
    FROM src
)

SELECT * FROM con_hash

{% if is_incremental() %}
WHERE _huella_contenido NOT IN (
    SELECT _huella_contenido FROM {{ this }}
    WHERE huella_registro IN (SELECT huella_registro FROM con_hash)
)
{% endif %}
