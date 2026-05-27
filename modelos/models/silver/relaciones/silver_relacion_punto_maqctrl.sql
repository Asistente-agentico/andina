-- rel_punto_maqctrl: vincula un punto de medición con las máquinas de control de polvo
-- que lo cubren. Relación N:M (un punto puede ser cubierto por varias máquinas y una máquina
-- puede cubrir varios puntos, según el catálogo DAND).
-- BK compuesta: punto_nro + ubicacion_tecnica.
-- Fuente: seed punto_maqctrl_cobertura (mapeo manual punto ↔ máquinas que lo cubren).
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['punto_nro', 'ubicacion_tecnica']) }}    AS huella_registro,
    {{ huella_registro(['punto_nro']) }}                          AS ent_punto_medicion_hk,
    {{ huella_registro(['ubicacion_tecnica']) }}                  AS ent_maquina_control_polvo_hk,
    punto_nro,
    ubicacion_tecnica,
    current_timestamp                                              AS _silver_loaded_at,
    'semillas.punto_maqctrl_cobertura'                             AS _silver_fuente

FROM (
    SELECT DISTINCT
        punto_nro,
        ubicacion_tecnica
    FROM {{ ref('punto_maqctrl_cobertura') }}
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['punto_nro', 'ubicacion_tecnica']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
