{% snapshot snap_puntos_molienda_convencional %}
{{
    config(
        unique_key='etiqueta',
        strategy='check',
        check_cols=['etiqueta']
    )
}}
SELECT * FROM {{ source('landing', 'puntos_molienda_convencional') }}
{% endsnapshot %}
