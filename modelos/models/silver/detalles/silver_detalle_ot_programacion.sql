-- det_ot_programacion: atributos descriptivos de la programación de la OT.
-- Atributos: fecha inicio programado, fecha inicio extrema, fecha liberación,
-- horas-hombre planificadas, duración planificada, personal programado, status del sistema.
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
        inicio_programado,
        fecha_inicio_extrema,
        fecha_liberacion,
        hh_planificadas,
        duracion_planificada,
        personal_prog,
        status_sistema
    FROM {{ ref('bronce_ot_ventilacion') }}
),

con_hash AS (
    SELECT
        {{ huella_registro(['orden_nro']) }}                                                                                                                                              AS huella_registro,
        {{ huella_contenido(['inicio_programado', 'fecha_inicio_extrema', 'fecha_liberacion', 'hh_planificadas', 'duracion_planificada', 'personal_prog', 'status_sistema']) }}            AS _huella_contenido,
        inicio_programado,
        fecha_inicio_extrema,
        fecha_liberacion,
        hh_planificadas,
        duracion_planificada,
        personal_prog,
        status_sistema,
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
