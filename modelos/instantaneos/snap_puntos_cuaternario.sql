{% snapshot snap_puntos_cuaternario %}
{{
    config(
        unique_key='etiqueta',
        strategy='check',
        check_cols=['etiqueta']
    )
}}
SELECT * FROM {{ source('landing', 'puntos_cuaternario') }}
{% endsnapshot %}
