with staking_rates as (
    select * from {{ ref('staking_Rates') }}
)

,staking_rates_adding_unique_row as(
    select 
    *
    ,row_number() over(order by xx, __source_ts_ms) as id -- creating id for window function in next step (next_datetime)
    , stakedAmount*dailyRewardPerUnit as reward_calc -- calculating reward on the staked amount
    FROM staking_rates
    order by __source_ts_ms
)

,staking_unique_row_date_format as(
    select 
    *
    ,TIMESTAMP_MILLIS(__source_ts_ms) AS datetime_format
    ,COALESCE(lead(TIMESTAMP_MILLIS(__source_ts_ms)) over(partition by xx order by id), TIMESTAMP '9999-12-31 23:59:59 UTC') as next_datetime_format
    FROM staking_rates_adding_unique_row
    order by __source_ts_ms
    )


,staking_rewards as (
    select * from {{ ref('staking_Rewards') }}
)

,date_format_staking_rewards as(
    select
    *
    ,TIMESTAMP_MILLIS(__source_ts_ms) AS datetime_format
    FROM staking_rewards
    where type="expected" -- we are looking at only expected rewards
      and not __deleted  -- looking at only non-deleted records in rewards
    order by __source_ts_ms
)

, date_series AS (
    -- created list of dates beginning '2023-07-01' to current date
    SELECT DATE(date) AS date_value
    FROM UNNEST(GENERATE_DATE_ARRAY('2023-07-01', CURRENT_DATE())) AS date
)


select 

    date_series.date_value as date
    ,rate_query.xx
    ,rewards_query.rewardXx
    ,rate_query.assetHold
    ,rate_query.assetReward 
    ,rewards_query.type
    ,rate_query.stakedAmount 
    ,rate_query.reward_calc
    ,rewards_query.amount -- this comes from 'stake_Rewards.csv': there are some cases where amount exists, but we do not have relevant foreign key in stake.Rewards.csv
    ,case when round(rate_query.reward_calc,4) = round(rewards_query.amount,4) then "yes" else "no"
    end as matching -- this is to check if our numbers are close

    from date_series
    left join staking_unique_row_date_format rate_query on date_series.date_value = date(rate_query.datetime_format)
    left join date_format_staking_rewards rewards_query on rewards_query.rewardXx = rate_query.xx
    AND rewards_query.datetime_format >= rate_query.datetime_format
    AND (rewards_query.datetime_format < COALESCE(rate_query.next_datetime_format, TIMESTAMP '9999-12-31 23:59:59 UTC'))
    -- where rewards_query.date>="2023-07-01"
    -- where reward_calc is not null

