-- det_medicion: atributos descriptivos del hecho atómico de medición.
-- Atributos: concentración mg/m³, fecha, hora de inicio, hora de término, estado, motivo si no se midió.
-- BK (huella_registro) referencia al link L_MEDICION (punto + semana).
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
        anio,
        semana_nro,
        concentracion_mg_m3,
        fecha_medicion,
        hora_inicio,
        hora_termino,
        estado,
        motivo_no_medicion
    FROM {{ ref('bronce_mediciones') }}
),

con_hash AS (
    SELECT
        {{ huella_registro(['punto_nro', 'anio', 'semana_nro']) }}                                                                                AS huella_registro,
        {{ huella_contenido(['concentracion_mg_m3', 'fecha_medicion', 'hora_inicio', 'hora_termino', 'estado', 'motivo_no_medicion']) }} AS _huella_contenido,
        concentracion_mg_m3,
        fecha_medicion,
        hora_inicio,
        hora_termino,
        estado,
        motivo_no_medicion,
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
