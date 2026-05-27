{% snapshot snap_puntos_prechancado %}
{{
    config(
        unique_key='etiqueta',
        strategy='check',
        check_cols=['etiqueta']
    )
}}
SELECT * FROM {{ source('landing', 'puntos_prechancado') }}
{% endsnapshot %}
