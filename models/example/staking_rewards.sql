-- {{ config(materialized='table') }}

with staking_rewards as (
    select * from {{ ref('staking_Rewards') }}
)

select * from staking_rewards