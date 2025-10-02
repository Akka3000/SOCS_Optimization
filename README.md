# Strategic Optimization of Charging Stations (SOCS)

This repository contains an AMPL MILP that **co-optimizes charging schedules and activity execution** for a fleet of battery-powered resources over a 168-hour horizon (1 week). The objective is to minimize **electricity cost + penalties** while respecting **battery dynamics, single-charger capacity, activity windows, and work-hour preferences**.

## Sets
- `RESOURCES = 1..7`
- `ACTIVITIES = 1..9`
- `TIME = 0..167` (hours)
- `WORK_HOURS` and `NON_WORK_HOURS` partition a 24h day (06–16 as work hours)

## Parameters (excerpt)
- `battery_capacity[res]` — kWh
- `charge_rate[res]` — kW
- `consumption_working[res]` — kWh per hour when engaged in activity
- `activity_start_window[res,act]`, `activity_end_window[res,act]`, `activity_duration[res,act]`
- `price[t]` — SEK/kWh
- `delay_penalty`, `outside_work_penalty`

## Decision variables (your original names)
- `charge[res,t] ∈ [0,1]` — 1 if resource `res` charges at hour `t`
- `battery_charge[res,t] ∈ [0, battery_capacity[res]]` — battery level
- `engaged_in_activity[res,act,t] ∈ [0,1]` — 1 if activity `act` is executed by `res` at `t`
- `actual_activity_start[res,act] ≥ 0` — chosen start time (hour index)
- `delay[res,act] ≥ 0` — positive if activity finishes after `activity_end_window`
- `outside_work[res,act] ≥ 0` — hours of activity placed in `NON_WORK_HOURS`

## Objective
```ampl
minimize Total_Cost:
    sum {res,t} price[t] * charge[res,t] * charge_rate[res]
  + sum {res,act} delay_penalty * delay[res,act]
  + sum {res,act} outside_work_penalty * outside_work[res,act];
```

## Core constraints (excerpt)
- **Battery recursion**  
  `battery_charge[res,t] = battery_charge[res,t-1] + charge[res,t]*charge_rate[res] − sum_act engaged_in_activity[res,act,t]*consumption_working[res]`
- **Initial battery**: `battery_charge[res,0] = battery_capacity[res]`
- **Single charger**: `sum_res charge[res,t] ≤ 1`
- **No overlap** (optional): `charge[res,t] + sum_act engaged_in_activity[res,act,t] ≤ 1`
- **One activity per hour**: `sum_act engaged_in_activity[res,act,t] ≤ 1`
- **Duration**: `sum_t engaged_in_activity[res,act,t] = activity_duration[res,act]`
- **Windows**: `activity_start_window ≤ actual_activity_start ≤ activity_end_window − duration` (delay covers overshoot)
- **Delay**: `delay[res,act] ≥ actual_activity_start[res,act] + activity_duration[res,act] − activity_end_window[res,act]`
- **Outside work**: `outside_work[res,act] = sum_{t∈NON_WORK_HOURS} engaged_in_activity[res,act,t]`

> Note: The model encodes contiguity of each activity through the time-windowed activation of `engaged_in_activity[res,act,t]` relative to `actual_activity_start[res,act]`.

## How to run (AMPL)
```ampl
reset;
option solver gurobi;  # or cplex / highs / scip

model SOCS.mod;
data  SOCS.dat;

solve;

# Inspect results
display charge;
display battery_charge;
display engaged_in_activity;
display actual_activity_start, delay, outside_work;
```

## Results

**Setup.**  
7 resources, 9 activities over 168 hours (1 week). Work hours: 06–16 daily.  
Model: MILP in AMPL, solved with Gurobi.

**Sensitivity analysis on final state of charge (SOC requirement):**

| Final SOC | Total Cost (SEK) | Delay (h) | Out-of-hours work (h) | Penalties (SEK) | Penalty Share |
|----------:|-----------------:|----------:|----------------------:|----------------:|--------------:|
| 20%       | 5,344.00         | 0         | 5                     | 5,000.00        | 93.56%        |
| 40%       | 5,850.40         | 0         | 5                     | 5,000.00        | 85.46%        |
| 60%       | 7,250.86         | 0         | 5                     | 5,000.00        | 68.96%        |
| 80%       | 12,589.73        | 0         | 7                     | 7,000.00        | 55.60%        |
| 100%      | 37,886.24        | 0         | 7                     | 7,000.00        | 18.48%        |

**Takeaways.**  
- Lower SOC targets minimize total cost but a very high share becomes penalties.  
- Higher SOC targets raise electricity costs drastically but reduce the relative weight of penalties.  
- The trade-off illustrates **cost efficiency vs operational robustness**.

## Repository layout (suggestion)
```
README.md
SOCS.mod
SOCS.dat
SOCS.run
```
