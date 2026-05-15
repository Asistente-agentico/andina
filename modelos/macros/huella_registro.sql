{% macro huella_registro(field_list) %}
    {{ return(dbt_utils.generate_surrogate_key(field_list)) }}
{% endmacro %}
