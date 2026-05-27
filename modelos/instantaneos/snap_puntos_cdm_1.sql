{% snapshot snap_puntos_cdm_1 %}
{{
    config(
        unique_key='etiqueta',
        strategy='check',
        check_cols=['etiqueta']
    )
}}
SELECT * FROM {{ source('landing', 'puntos_cdm_1') }}
{% endsnapshot %}
