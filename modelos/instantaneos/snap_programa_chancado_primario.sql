{% snapshot snap_programa_chancado_primario %}
{{
    config(
        unique_key='orden_nro',
        strategy='check',
        check_cols=['orden_nro']
    )
}}
SELECT * FROM {{ source('landing', 'programa_chancado_primario') }}
{% endsnapshot %}
