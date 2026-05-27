-- det_ot_ejecucion: atributos descriptivos de la ejecución real de la OT.
-- Atributos: cumplimiento del programa, horas-hombre reales, personal real, duración real,
-- adherencia al programa, día efectivo de ejecución.
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
        cumpl_prog,
        hh_reales,
        personal_real,
        duracion_real,
        adherencia_prog,
        dia_ejecutado
    FROM {{ ref('bronce_ot_ventilacion') }}
),

con_hash AS (
    SELECT
        {{ huella_registro(['orden_nro']) }}                                                                                                  AS huella_registro,
        {{ huella_contenido(['cumpl_prog', 'hh_reales', 'personal_real', 'duracion_real', 'adherencia_prog', 'dia_ejecutado']) }}             AS _huella_contenido,
        cumpl_prog,
        hh_reales,
        personal_real,
        duracion_real,
        adherencia_prog,
        dia_ejecutado,
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
