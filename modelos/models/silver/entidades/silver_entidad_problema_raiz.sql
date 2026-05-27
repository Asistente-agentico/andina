-- ent_problema_raiz: una fila por problema raíz del modelo causal V1.
-- BK: problema_raiz_codigo (código único del problema raíz).
-- Fuente: seed problemas_raiz (catálogo estático del modelo causal).
-- Ejemplos: defecto_componente_correa, maquina_control_detenida, condicion_ambiental_aseo, etc.
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['problema_raiz_codigo']) }}    AS huella_registro,
    problema_raiz_codigo,
    current_timestamp                                    AS _silver_loaded_at,
    'semillas.problemas_raiz'                            AS _silver_fuente

FROM (
    SELECT DISTINCT
        problema_raiz_codigo
    FROM {{ ref('problemas_raiz') }}
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['problema_raiz_codigo']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
