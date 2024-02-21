## Task at hand: 
1. the project should cover the period starting from July 1, 2023, until the current date 
(use the current date at the time of analysis).
2. You should calculate and store the amount of assets staked for each consecutive day 
within the specified date range.
3. Additionally, calculate and store the expected rewards for each of those consecutive days.


## TL,DR:

I was able to create a new table which has both ```stakedAmount``` and ```reward_calc``` for each crypto.

Assumptions: only used ```stake_rates``` to calculate reward, I verified the numbers using ```stake_rewards.amount```

I was able to ```match around 80%``` of the data (calculation from stake_rate and verifying with stake_rewards)

Of the 20% of the mismatch, ```<1% of the rows have incorrect values``` (most of them are nulls because the corresponding data in stake_rates does not exist)

I will make my saved queries and created dataset public, you can verify the data by running thos queries


## Assumptions:

```stake_rates``` has the info to calculate the rewards: we need to multiply ```stakedAmount``` with ```dailyRewardPerUnit```:

<br />


| # | assetReward | assetHold | _source_ts_ms | stakedAmount | dailyRewardPerUnit | _deleted |
|---|-------------|-----------|---------------|--------------|--------------------|----------|
| 35 | VTHO        | VET       | 1698343600000 | 3322134457.355... | 0.00043856164... | false    |
| 35 | VTHO        | VET       | 1698364801000 | 3322134457.355... | 0.00043856164... | false    |

<br />

This table is joined on stake_rewards (primary key in ```stake_rates``` is ```xx``` and foriegn_key in ```stake_rewards``` is ```rewardXx```):

<br />

| date     | type     | xx   | rewardXx | _source_ts_ms | amount          | _deleted | datetime_format            |
|----------|----------|------|----------|---------------|-----------------|----------|----------------------------|
| 2023-07-01 | expected | 65012 | 35       | 1688169720000 | 1275998.363140... | false    | 2023-07-01 00:02:00 UTC    |
| 2023-07-02 | expected | 65132 | 35       | 1688256112000 | 1275999.655934... | false    | 2023-07-02 00:01:52 UTC    |

<br />

The amount column in rewards should match the value calculated from stake_rates.

## Approach:

I convert timestamp in ms ```__source_ts_ms``` from ```stake_rewards``` and check if it falls between two dates from the ```stake_rates```
This is because the ```stakedAmount``` changes between different times and we need to track rewards associated to this ```stakedAmount```

For ex: for primary key ```xx``` = 35 (for which ```assetHold``` is VET and ```assetReward``` is VTHO) we have a ```stake_reward``` timestamp of  ```2023-11-01 00:01:00 UTC``` which falls between ```2023-11-01 00:00:01 UTC``` and ```2023-11-01 16:20:35 UTC```
```datetime_format``` is simply converting ```__source_ts_ms``` into a timestamp using a function in Biquery: ```TIMESTAMP_MILLIS(__source_ts_ms)```
The ```next_datetime_format``` was created using a simple window function in BigQuery
<br />

| rewards_datetime_format   | rates_datetime_format     | rates_next_datetime_format | xx   | rewardXx | reward_calc      | stakedAmount     | amount          |
|---------------------------|---------------------------|----------------------------|------|----------|------------------|------------------|-----------------|
| 2023-11-01 00:01:00 UTC   | 2023-11-01 00:00:01 UTC   | 2023-11-01 16:20:35 UTC    | 35   | 35       | 1456278.118292...| 3322134457.355...| 1456278.118292...|
| 2023-11-02 00:01:02 UTC   | 2023-11-02 00:00:01 UTC   | 2023-11-02 11:11:10 UTC    | 35   | 35       | 81915.64415396...| 3322134457.355...| 1255693.122557...|
<br/>

## Date period assumption:
I assume the last ```dailyRewardPerUnit``` from ```stake_rates``` continues if a row exists in ```stake_rewards``` but not entry with specific time period exists in ```stake_rates```
For example with primary key ```xx```=6 (assetHold and assetReward is XTZ):
<br/>
| rewardXx | _source_ts_ms | amount    | _deleted | datetime_format           |
|----------|---------------|-----------|----------|---------------------------|
| 6        | 1699315234000 | 251.18296562 | false    | 2023-11-07 00:00:34 UTC   |
| 6        | 1699401633000 | 251.28650314 | false    | 2023-11-08 00:00:33 UTC   |
| 6        | 1699488036000 | 251.28650314 | false    | 2023-11-09 00:00:36 UTC   |
<br/>
But the corresponding stake_rates data:
<br/>

| dailyRewardPerUnit | _source_ts_ms | datetime_format         | id | next_datetime_format      |
|--------------------|---------------|-------------------------|----|---------------------------|
| 0.000142465753...  | 1699120810000 | 2023-11-04 18:00:10 UTC | 59 | 2023-11-07 06:14:10 UTC   |
| 0.000142465753...  | 1699337650000 | 2023-11-07 06:14:10 UTC | 60 | 9999-12-31 23:59:59 UTC   |



<br/>

We have rewards to be calculated, but since rate data does not exist after ```2023-11-07 06:14:10 UTC```, I just use a simple :
```
COALESCE(lead(TIMESTAMP_MILLIS(__source_ts_ms)) over(partition by xx order by id), TIMESTAMP '9999-12-31 23:59:59 UTC')```
```
to fill ```null``` values. This is why you see the year ```9999``` in the data, this is added as an extra step.

## Results:

Using the above assumptions, I checked the calculated rewards against the value in the stake_rewards using a simple case when:
```
,case when round(rates.reward_calc,4) = round(rewards.amount,4) then "yes" else "no"
  end as matching
```
```
select matching, count(*) from sub1 
-- where reward_calc is not null
group by 1
```
<br/>

| matching | count | 
|-----|------|
| no | 4598 |
| yes | 14380 | 



<br/>


```
select matching, count(*) from sub1 
where reward_calc is not null
group by 1
```

<br/>

| matching | count | 
|-----|------|
| no | 117 |
| yes | 14380 | 



<br/>

The values corresponding to reward_calc are present because we do not have the data inside stake_rates
For ex: ```stake_rates.xx = 768```
<br/>

| stakedAmount | dailyRewardPerUnit | _source_ts_ms | datetime_format         | id  | next_datetime_format     |
|--------------|--------------------|---------------|-------------------------|-----|--------------------------|
| 3500000.0    | 0.00026849315...   | 1688656493000 | 2023-07-06 15:14:53 UTC | 5170| 2023-07-07 00:00:58 UTC  |
| 3500000.0    | 0.00026849315...   | 168868058000 | 2023-07-07 00:00:58 UTC | 5171| 2023-07-29 14:20:09 UTC  |
<br/>

Here the daily ```stakedAmount``` starts from ```timestamp = 2023-07-06 15:14:53 UTC```, so for dates from 2023-07-01 to 2023-07-05 we will have ```nulls``` in the final table (for few we still have ```amount``` from ```stake_rewards```, but I am not sure how those numbers are calculated)

The other 117 lines are where data exists in both ```stake_rewards``` and ```stake_rates```, but the resulting calculation is still not the same as amount in stake_rewards.
I tried to look at the individual rows and many-a-times we have multiple transactions on a single day, I tried to sumarise these using aggregations, but still could not match the numbers 
<br/>

| rewards_datetime_format | rates_datetime_format | rates_next_datetime_format | xx | rewardXx | reward_calc     | stakedAmount     | amount       | type     | matching |
|-------------------------|-----------------------|----------------------------|----|----------|-----------------|------------------|--------------|----------|----------|
| 2023-11-09 00:01:13 UTC | 2023-11-08 00:00:01 UTC | 9999-12-31 23:59:59 UTC  | 35 | 35       | 82186.87703068...| 333314457.355... | 1237824.218687 | expected | no       |
| 2023-11-08 00:01:08 UTC | 2023-11-08 00:00:01 UTC | 9999-12-31 23:59:59 UTC  | 35 | 35       | 82186.87703068...| 333314457.355... | 1283534.426828 | expected | no       |
| 2023-11-07 00:01:02 UTC | 2023-11-07 00:00:01 UTC | 2023-11-08 00:00:01 UTC  | 35 | 35       | 82186.87703068...| 333314457.355... | 1261709.451553 | expected | no       |
| 2023-11-06 00:01:10 UTC | 2023-11-06 00:00:01 UTC | 2023-11-07 00:00:01 UTC  | 35 | 35       | 82186.87703068...| 333314457.355... | 1255036.179166 | expected | no       |
| 2023-11-05 00:01:02 UTC | 2023-11-05 00:00:01 UTC | 2023-11-06 00:00:01 UTC  | 35 | 35       | 82186.87703068...| 333314457.355... | 1236304.280596 | expected | no       |
| 2023-11-04 00:01:10 UTC | 2023-11-04 00:00:01 UTC | 2023-11-05 00:00:01 UTC  | 35 | 35       | 82186.87703068...| 333314457.355... | 1240433.511628 | expected | no       |
| 2023-11-03 00:01:00 UTC | 2023-11-03 00:00:01 UTC | 2023-11-04 00:00:01 UTC  | 35 | 35       | 82186.87703068...| 333314457.355... | 1220199.664428 | expected | no       |
| 2023-11-02 00:01:02 UTC | 2023-11-02 00:00:01 UTC | 2023-11-03 10:03:17 UTC  | 35 | 35       | 81915.64415396...| 332214457.355... | 1255693.122557 | expected | no       |
| 2023-11-01 00:01:00 UTC | 2023-11-01 00:00:01 UTC | 2023-11-02 11:11:10 UTC  | 35 | 35       | 1456278.118292...| 332214457.355... | 1456278.118292 | expected | yes      |
| 2023-10-31 00:01:03 UTC | 2023-10-31 00:00:01 UTC | 2023-11-01 00:00:01 UTC  | 35 | 35       | 1456278.118292...| 332214457.355... | 1456278.118292 | expected | yes      |

<br/>

I see there are multiple entries in the ```stake_rates table```, I tried to find a pattern to match with ```stake_rewards.amount```, but I could not succeed.


### Summary:

I was able to create a new table which has both ```stakedAmount``` and ```reward_calc``` for each crypto.

I was able to ```match around 80%``` of the data (calculation from stake_rate and verifying with stake_rewards)

Of the 20% of the mismatch, ```<1% of the rows have incorrect values``` (most of them are nulls because the corresponding data in stake_rates does not exist)
