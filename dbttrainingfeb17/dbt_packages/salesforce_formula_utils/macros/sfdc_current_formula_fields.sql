{% macro sfdc_current_formula_values(table, column, join_to_table, order_by='count(*) desc', max_records=none, default=none) -%}x

    {#-- Prevent querying of db in parsing mode. This works because this macro does not create any new refs. #}
    {%- if not execute -%}
        {{ return('') }}
    {% endif %}

    {%- set target_relation = table -%}

    {%- call statement('get_column_values', fetch_result=true) %}

        {%- if not target_relation and default is none -%}

          {{ exceptions.raise_compiler_error("In get_column_values(): relation " ~ table ~ " does not exist and no default value was provided.") }}

        {%- elif not target_relation and default is not none -%}

          {{ log("Relation " ~ table ~ " does not exist. Returning the default value: " ~ default) }}

          {{ return(default) }}

        {%- else -%}


            select
                {{ column }} as value

            from {{ target_relation }}
            where lower(object) = lower('{{ join_to_table }}')
            group by {{ column }}
            order by {{ order_by }}

            {% if max_records is not none %}
            limit {{ max_records }}
            {% endif %}

        {% endif %}

    {%- endcall -%}

    {%- set value_list = load_result('get_column_values') -%}

    {%- if value_list and value_list['data'] -%}
        {%- set values = value_list['data'] | map(attribute=0) | list %}
        {{ return(values) }}
    {%- else -%}
        {{ return(default) }}
    {%- endif -%}

{%- endmacro %}