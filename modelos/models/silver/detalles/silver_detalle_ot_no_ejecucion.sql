-- det_ot_no_ejecucion: atributos descriptivos de las OT que no se ejecutaron en la fecha programada.
-- Atributos: motivo principal de la no-ejecución, peso del motivo, fecha de reprogramación.
-- Motivos: falta_repuestos (0.90) > no_entrega_operaciones (0.70) > falta_personal (0.60).
-- Aplica solo cuando cumpl_prog = 0.
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
        motivo_no_ejecucion,
        peso_motivo,
        fecha_reprogramacion
    FROM {{ ref('bronce_ot_ventilacion') }}
    WHERE cumpl_prog = 0
),

con_hash AS (
    SELECT
        {{ huella_registro(['orden_nro']) }}                                                          AS huella_registro,
        {{ huella_contenido(['motivo_no_ejecucion', 'peso_motivo', 'fecha_reprogramacion']) }}        AS _huella_contenido,
        motivo_no_ejecucion,
        peso_motivo,
        fecha_reprogramacion,
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
