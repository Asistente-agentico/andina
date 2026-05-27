{% snapshot snap_puntos_terciario %}
{{
    config(
        unique_key='etiqueta',
        strategy='check',
        check_cols=['etiqueta']
    )
}}
SELECT * FROM {{ source('landing', 'puntos_terciario') }}
{% endsnapshot %}
