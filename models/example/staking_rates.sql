{{ config(materialized='table') }}

with staking_rates as (
    select * from {{ ref('staking_Rates') }}
)

select * from staking_rates