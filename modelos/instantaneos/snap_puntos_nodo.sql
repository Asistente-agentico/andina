{% snapshot snap_puntos_nodo %}
{{
    config(
        unique_key='etiqueta',
        strategy='check',
        check_cols=['etiqueta']
    )
}}
SELECT * FROM {{ source('landing', 'puntos_nodo') }}
{% endsnapshot %}
