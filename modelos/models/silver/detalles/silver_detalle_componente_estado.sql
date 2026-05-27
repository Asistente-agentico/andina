-- det_componente_estado: estado y severidad del componente estructural a lo largo del tiempo.
-- Atributos que cambian: estado_actual (operativo/defectuoso), severidad, fecha_inspeccion.
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
        componente_codigo,
        estado_actual,
        severidad,
        fecha_inspeccion
    FROM {{ ref('componentes_estado_semanal') }}
),

con_hash AS (
    SELECT
        {{ huella_registro(['componente_codigo']) }}                          AS huella_registro,
        {{ huella_contenido(['estado_actual', 'severidad', 'fecha_inspeccion']) }} AS _huella_contenido,
        estado_actual,
        severidad,
        fecha_inspeccion,
        current_timestamp                       AS valid_from,
        NULL::TIMESTAMP                         AS valid_to,
        1                                       AS version_seq,
        'semillas.componentes_estado_semanal'   AS _silver_fuente
    FROM src
)

SELECT * FROM con_hash

{% if is_incremental() %}
WHERE _huella_contenido NOT IN (
    SELECT _huella_contenido FROM {{ this }}
    WHERE huella_registro IN (SELECT huella_registro FROM con_hash)
)
{% endif %}
