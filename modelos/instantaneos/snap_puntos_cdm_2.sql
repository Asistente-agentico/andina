{% snapshot snap_puntos_cdm_2 %}
{{
    config(
        unique_key='etiqueta',
        strategy='check',
        check_cols=['etiqueta']
    )
}}
SELECT * FROM {{ source('landing', 'puntos_cdm_2') }}
{% endsnapshot %}
