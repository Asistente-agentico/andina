-- det_maquina_generadora: atributos descriptivos de la máquina generadora de polvo.
-- Atributos: nombre, tipo (correa/harnero/alimentador/chancador), descripción.
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
        maquina_gen_codigo,
        maquina_gen_nombre,
        tipo_maquina_gen,
        descripcion
    FROM {{ ref('bronce_mediciones') }}
    WHERE maquina_gen_codigo IS NOT NULL
),

con_hash AS (
    SELECT
        {{ huella_registro(['maquina_gen_codigo']) }}                                  AS huella_registro,
        {{ huella_contenido(['maquina_gen_nombre', 'tipo_maquina_gen', 'descripcion']) }} AS _huella_contenido,
        maquina_gen_nombre,
        tipo_maquina_gen,
        descripcion,
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
