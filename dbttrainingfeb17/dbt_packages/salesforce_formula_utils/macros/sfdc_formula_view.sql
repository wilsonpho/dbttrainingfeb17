{%- macro sfdc_formula_view(source_table, source_name='salesforce', reserved_table_name=source_table, fields_to_include=none, full_statement_version=true, materialization='view', using_quoted_identifiers=False) -%}

-- Best practice for this model is to be materialized as view. That is why we have set that here.
{{
    config(
        materialized = materialization
    )
}}

/*
    The below sets the old_formula_fields variable to the results of the get_column_values results which queries the field column from the fivetran_formula table.
    The logic here is that the variable will be a list of all current salesforce formula field names. This list is then used within the dbt_utils.star operation to exclude them.
    This allows users with the Fivetran legacy Salesforce fields to ignore them and be replaced by the new fields.
*/

{% if full_statement_version %}
{% if using_quoted_identifiers %}
{%- set table_results = dbt_utils.get_column_values(table=source(source_name, 'fivetran_formula_model'), 
                                                    column='"MODEL"' if target.type in ('snowflake') else '"model"' if target.type in ('postgres', 'redshift', 'snowflake') else '`model`', 
                                                    where=("\"OBJECT\" = '" if target.type in ('snowflake') else "\"object\" = '" if target.type in ('postgres', 'redshift') else "`object` = '") ~ source_table ~ "'") -%}

{% else %}
{%- set table_results = dbt_utils.get_column_values(table=source(source_name, 'fivetran_formula_model'), column='model', where="object = '" ~ source_table ~ "'") -%}

{% endif %}

{{ table_results[0] }}

{% else %}

{%- set current_formula_fields = (salesforce_formula_utils.sfdc_current_formula_values(source(source_name, 'fivetran_formula'),'field',source_table)) | upper -%}  --In Snowflake the fields are case sensitive in order to determine if there are duplicates.

-- defaults to all formula fields if fields_to_include is none
{% if fields_to_include is none %}
    {% set fields_to_include = current_formula_fields | lower %}
{% endif %}

    select

        {{ salesforce_formula_utils.sfdc_star_exact(source(source_name,source_table), relation_alias=(source_table + "__table"), except=current_formula_fields) }} --Querying the source table and excluding the old formula fields if they are present.

        {{ salesforce_formula_utils.sfdc_formula_view_fields(join_to_table=source_table, source_name=source_name, inclusion_fields=fields_to_include) }} --Adds the field names for records that leverage the view_sql logic.

        {{ salesforce_formula_utils.sfdc_formula_pivot(join_to_table=source_table, source_name=source_name, added_inclusion_fields=fields_to_include) }} --Adds the results of the sfdc_formula_pivot macro as the remainder of the sql query.

    from {{ source(source_name,source_table) }} as {{ source_table }}__table

    {{ salesforce_formula_utils.sfdc_formula_view_sql(join_to_table=source_table, source_name=source_name, inclusion_fields=fields_to_include) }} --If view_sql logic is used, queries are inserted here as well as the where clause.
{% endif %}
{%- endmacro -%}
