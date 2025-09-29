# Defining the time set and resources set
set ACTIVITIES := 1..9;  										     # Three different activities
set TIME := 0..167;     											 # Time periods from 0 to 167 (hours)
set RESOURCES := 1..7;  											 # 7 resources
set WORK_HOURS := {h in TIME: (h mod 24) >= 6 and (h mod 24) <= 16}; # Working hours
set NON_WORK_HOURS := TIME diff WORK_HOURS;						     # Non-working hours


# Parameters
param battery_capacity {RESOURCES};          					    # Battery capacity in kWh for each resource
param charge_rate {RESOURCES};             						    # Charging rate in kW for each resource
param consumption_working {RESOURCES};      					    # Battery consumption per hour while working (kWh)
param activity_start_window {res in RESOURCES, act in ACTIVITIES};  # Earliest start time for each activity
param activity_end_window {res in RESOURCES, act in ACTIVITIES};    # Latest end time for each activity
param activity_duration {res in RESOURCES, act in ACTIVITIES};      # Duration of each activity
param price {TIME};                          				        # Electricity prices for each hour
param delay_penalty; 					   						    # Cost per hour of delay
param outside_work_penalty;                  				        # Cost for working outside of working hours

# Variables
var charge {res in RESOURCES, t in TIME} >= 0, <= 1; 								  # Charging status
var battery_charge {res in RESOURCES, t in TIME} >= 0, <= battery_capacity[res];      # Battery level
var engaged_in_activity {res in RESOURCES, act in ACTIVITIES, t in TIME} >= 0, <= 1;  # Activity status
var actual_activity_start {res in RESOURCES, act in ACTIVITIES} >= 0;                 # Actual start time for each activity
var delay {res in RESOURCES, act in ACTIVITIES} >= 0; 								  # Delay in hours
var outside_work {res in RESOURCES, act in ACTIVITIES} >= 0; 						  # Total hours worked outside working hours


# Objective function: Minimize the total cost of charging
minimize Total_Cost:
    sum {res in RESOURCES, t in TIME} price[t] * charge[res, t] * charge_rate[res] +
    sum {res in RESOURCES, act in ACTIVITIES} delay_penalty * delay[res, act] +
    sum {res in RESOURCES, act in ACTIVITIES} outside_work_penalty * outside_work[res, act];
    
# Constraints
# Battery level update constraint
subject to Battery_Charging {res in RESOURCES, t in TIME: t > 0}:
    battery_charge[res, t] = battery_charge[res, t-1] +
                             charge[res, t] * charge_rate[res] -
                             sum {act in ACTIVITIES} engaged_in_activity[res, act, t] * consumption_working[res];
       
# Initial battery level starts at full capacity
subject to Initial_Battery_Level {res in RESOURCES}:
    battery_charge[res, 0] = battery_capacity[res];

# Battery level cannot drop below 0 or exceed capacity
subject to Battery_Capacity_Limits {res in RESOURCES, t in TIME}:
    battery_charge[res, t] >= 0;

# Ensure the battery charge does not exceed its capacity
subject to Max_Battery_Capacity {res in RESOURCES, t in TIME}:
    battery_charge[res, t] <= battery_capacity[res];

# Ensure the activity engagement aligns with the start time and duration
subject to Flexible_Activity_Schedule {res in RESOURCES, act in ACTIVITIES, t in TIME}:
    engaged_in_activity[res, act, t] <= 
    (if t >= actual_activity_start[res, act] and 
        t < actual_activity_start[res, act] + activity_duration[res, act] then 1 else 0);

# Ensure the actual activity start time is within the allowed start window
subject to Activity_Start_Window {res in RESOURCES, act in ACTIVITIES}:
    actual_activity_start[res, act] >= activity_start_window[res, act];

# Ensure the activity duration does not exceed the allowed end window
subject to Activity_End_Window {res in RESOURCES, act in ACTIVITIES}:
    actual_activity_start[res, act] + activity_duration[res, act] <= activity_end_window[res, act] + delay[res, act];

# Enforce that the total activity engagement matches the activity duration
subject to Activity_Duration_Enforcement {res in RESOURCES, act in ACTIVITIES}:
    sum {t in TIME} engaged_in_activity[res, act, t] = activity_duration[res, act];

# Ensure charging and activity do not overlap
subject to Charging_Activity_Overlap {res in RESOURCES, t in TIME}:
    charge[res, t] + sum {act in ACTIVITIES} engaged_in_activity[res, act, t] <= 1;

#Only one resource can charge at a time
subject to Single_Charging_Station {t in TIME}:
    sum {res in RESOURCES} charge[res, t] <= 1;
    
# Ensure each resource is engaged in at most one activity at any given time
subject to Resource_Activity_Exclusivity {res in RESOURCES, t in TIME}:
    sum {act in ACTIVITIES} engaged_in_activity[res, act, t] <= 1;
    
# Ensure proactive charging to prevent battery depletion in the next period (4%)
subject to Proactive_Charging {res in RESOURCES, t in TIME: t < card(TIME) - 1}:
    battery_charge[res, t] - sum {act in ACTIVITIES} (engaged_in_activity[res, act, t+1] * consumption_working[res])
    >= 0.04 * battery_capacity[res];
    
# Ensure each resource has at least 80% of its maximum capacity at the end of the time period
subject to end_target {res in RESOURCES}:
 battery_charge[res, 167] >= 0.8 * battery_capacity[res];
    
    # Ensure activities are completed in ascending order
subject to Activity_Sequence {res in RESOURCES, act in 1..(card(ACTIVITIES) - 1)}:
    actual_activity_start[res, act] + activity_duration[res, act] <= actual_activity_start[res, act + 1];
    
# Ensure valid activity windows
subject to Valid_Activity_Windows {res in RESOURCES, act in ACTIVITIES}:
    activity_start_window[res, act] <= activity_end_window[res, act] - activity_duration[res, act];

# Calculating Delay, ensuring delay is only positive when an activity exceeds its activity_end_window
subject to Calculate_Delay {res in RESOURCES, act in ACTIVITIES}:
    delay[res, act] >= actual_activity_start[res, act] + activity_duration[res, act] - activity_end_window[res, act];
    
# Calculate the total hours a resource spends engaged in an activity during non-working hours
subject to Calculate_Outside_Work_Hours {res in RESOURCES, act in ACTIVITIES}:
outside_work[res, act] = sum {t in NON_WORK_HOURS} engaged_in_activity[res, act, t];

    