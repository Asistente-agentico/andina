-- ent_perfil_usuario: una fila por perfil de gobernanza del producto Illari.
-- BK: perfil_codigo (gerente, jefe_fiscalizacion, jefe_mantencion).
-- Fuente: seed perfiles_usuario (catálogo estático del dominio).
-- Determina qué plantas y ámbitos puede ver cada usuario via L_USUARIO_GOBERNANZA.
{{
    config(
        materialized='incremental',
        unique_key='huella_registro',
        incremental_strategy='append',
        tags=['capa:silver', 'dominio:codelco_andina']
    )
}}

SELECT
    {{ huella_registro(['perfil_codigo']) }}    AS huella_registro,
    perfil_codigo,
    current_timestamp                            AS _silver_loaded_at,
    'semillas.perfiles_usuario'                  AS _silver_fuente

FROM (
    SELECT DISTINCT
        perfil_codigo
    FROM {{ ref('perfiles_usuario') }}
) t

{% if is_incremental() %}
WHERE {{ huella_registro(['perfil_codigo']) }} NOT IN (SELECT huella_registro FROM {{ this }})
{% endif %}
