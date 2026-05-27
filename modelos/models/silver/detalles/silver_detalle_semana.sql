-- det_semana: atributos descriptivos de la semana ISO.
-- Atributos: fecha de inicio (lunes), fecha de fin (domingo), trimestre, mes.
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
        anio,
        semana_nro,
        fecha_inicio_semana,
        fecha_fin_semana,
        trimestre,
        mes
    FROM {{ ref('calendario_semanas') }}
),

con_hash AS (
    SELECT
        {{ huella_registro(['anio', 'semana_nro']) }}                                                AS huella_registro,
        {{ huella_contenido(['fecha_inicio_semana', 'fecha_fin_semana', 'trimestre', 'mes']) }}      AS _huella_contenido,
        fecha_inicio_semana,
        fecha_fin_semana,
        trimestre,
        mes,
        current_timestamp                AS valid_from,
        NULL::TIMESTAMP                  AS valid_to,
        1                                AS version_seq,
        'semillas.calendario_semanas'    AS _silver_fuente
    FROM src
)

SELECT * FROM con_hash

{% if is_incremental() %}
WHERE _huella_contenido NOT IN (
    SELECT _huella_contenido FROM {{ this }}
    WHERE huella_registro IN (SELECT huella_registro FROM con_hash)
)
{% endif %}
