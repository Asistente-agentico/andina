-- det_maquina_control_polvo: atributos descriptivos de la máquina de control de polvo.
-- Atributos: denominación, tipo (HDP/CDP/EPZ/...), familia (renovacion_aire/abatidor_polvo), sector.
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
        ubicacion_tecnica,
        equipo_denom,
        tipo_equipo,
        familia_equipo,
        sector
    FROM {{ ref('bronce_equipos_ventilacion') }}
),

con_hash AS (
    SELECT
        {{ huella_registro(['ubicacion_tecnica']) }}                                       AS huella_registro,
        {{ huella_contenido(['equipo_denom', 'tipo_equipo', 'familia_equipo', 'sector']) }} AS _huella_contenido,
        equipo_denom,
        tipo_equipo,
        familia_equipo,
        sector,
        current_timestamp                AS valid_from,
        NULL::TIMESTAMP                  AS valid_to,
        1                                AS version_seq,
        'bronce_equipos_ventilacion'     AS _silver_fuente
    FROM src
)

SELECT * FROM con_hash

{% if is_incremental() %}
WHERE _huella_contenido NOT IN (
    SELECT _huella_contenido FROM {{ this }}
    WHERE huella_registro IN (SELECT huella_registro FROM con_hash)
)
{% endif %}
