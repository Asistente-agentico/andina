{% snapshot snap_puntos_chancado_2_3 %}
{{
    config(
        unique_key='etiqueta',
        strategy='check',
        check_cols=['etiqueta']
    )
}}
SELECT * FROM {{ source('landing', 'puntos_chancado_2_3') }}
{% endsnapshot %}
