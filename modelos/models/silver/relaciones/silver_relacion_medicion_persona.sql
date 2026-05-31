-- rel_medicion_persona: vincula una medición (punto + semana) con la persona que la realizó,
-- diferenciando el rol (operador de panel / técnico en higiene).
-- Resuelve el alias del bronce (operador_alias / tecnico_alias) contra el catálogo personas_alias
-- (alias_fuente → dni), de modo que el link apunta al hub persona por su BK real (dni).
-- BK compuesta: punto_nro + anio + semana_nro + dni + rol.
-- Fuente: bronce_mediciones + seed personas_alias.
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

WITH medicion AS (
    SELECT DISTINCT
        punto_nro,
        anio,
        semana_nro,
        operador_alias,
        tecnico_alias
    FROM {{ ref('bronce_mediciones') }}
    WHERE estado = 'medido'
),

-- Catálogo alias → dni (normalizado para join robusto)
alias_map AS (
    SELECT DISTINCT
        lower(trim(alias_fuente))   AS alias_norm,
        dni,
        tipo_dni,
        dni_pais_emisor
    FROM {{ ref('personas_alias') }}
),

operador AS (
    SELECT
        m.punto_nro, m.anio, m.semana_nro,
        'operador'::text            AS rol,
        a.dni, a.tipo_dni, a.dni_pais_emisor
    FROM medicion m
    JOIN alias_map a
        ON lower(trim(m.operador_alias)) = a.alias_norm
),

tecnico AS (
    SELECT
        m.punto_nro, m.anio, m.semana_nro,
        'tecnico'::text             AS rol,
        a.dni, a.tipo_dni, a.dni_pais_emisor
    FROM medicion m
    JOIN alias_map a
        ON lower(trim(m.tecnico_alias)) = a.alias_norm
),

roles AS (
    SELECT * FROM operador
    UNION ALL
    SELECT * FROM tecnico
)

SELECT
    {{ huella_registro(['punto_nro', 'anio', 'semana_nro', 'dni', 'rol']) }}  AS huella_registro,
    {{ huella_registro(['punto_nro']) }}                                       AS ent_punto_medicion_hk,
    {{ huella_registro(['anio', 'semana_nro']) }}                              AS ent_semana_hk,
    {{ huella_registro(['dni', 'tipo_dni', 'dni_pais_emisor']) }}              AS ent_persona_hk,
    punto_nro,
    anio,
    semana_nro,
    rol,
    dni,
    current_timestamp                                                          AS _silver_loaded_at,
    'bronce_mediciones'                                                        AS _silver_fuente

FROM roles

{% if is_incremental() %}
WHERE {{ huella_registro(['punto_nro', 'anio', 'semana_nro', 'dni', 'rol']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
