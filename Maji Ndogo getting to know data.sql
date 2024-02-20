-- Getting to know our data
SHOW TABLES;
SELECT * FROM employee
LIMIT 5;
SELECT * FROM global_water_access
LIMIT 5;
SELECT * FROM location
LIMIT 5;
SELECT * FROM visits
LIMIT 5;
SELECT * FROM water_quality
LIMIT 5;
SELECT * FROM water_source
LIMIT 5;
SELECT * FROM well_pollution
LIMIT 5;

-- identify all the unique data sources
SELECT distinct type_of_water_source FROM water_source;

-- VISITS TO WATER SOURCES
-- records where time_in_queue is more than 500 mins
SELECT * FROM visits
WHERE time_in_queue > 500;

-- Assess the water quality from the sources
-- find records where the subject_quality_score is 10 -- only looking for home taps -- and where the source
-- was visited a second time.
SELECT * FROM water_quality
WHERE subjective_quality_score= 10 AND visit_count =2;

-- investigating pollution issues
SELECT * FROM well_pollution
LIMIT 5;

-- checks if the results is Clean but the biological column is > 0.01.
SELECT * FROM well_pollution
WHERE results = "Clean" and biological>0.01;


-- identify the records that mistakenly have the word Clean in the description.
SELECT * FROM well_pollution
WHERE description LIKE "%Clean %";
-- Case 1a: Update descriptions that mistakenly mention
-- `Clean Bacteria: E. coli` to `Bacteria: E. coli`
UPDATE well_pollution
SET 
description = "Bacteria: E. coli"
WHERE 
description = "Clean Bacteria: E. coli";

-- Case 1b: Update the descriptions that mistakenly mention
-- `Clean Bacteria: Giardia Lamblia` to `Bacteria: Giardia Lamblia
UPDATE well_pollution
SET 
description= "Bacteria: Giardia Lamblia"
WHERE
description="Clean Bacteria: Giardia Lamblia";

-- Case 2: Update the `result` to `Contaminated: Biological` where
-- `biological` is greater than 0.01 plus current results is `Clean`
UPDATE well_pollution
SET 
results = "Contaminated: Biological"
WHERE 
biological > 0.01 AND results="Clean";

-- CLEANING OUR DATA
-- add employees' email addresses 
-- We can determine the email address for each employee by:
-- selecting the employee_name column
-- replacing the space with a full stop
-- make it lowercase
-- and stitch it all together
SELECT 
CONCAT(LOWER(REPLACE(employee_name, ' ','.')), '@ndogowater.gov') as new_email
from employee;
UPDATE employee
SET email=CONCAT(LOWER(REPLACE(employee_name, ' ','.')), '@ndogowater.gov');

-- checking the length of the phone numbers
SELECT
LENGTH(phone_number)
FROM
employee;
-- remove the trailing space using trim()
select 
length(trim(phone_number))
from employee;

UPDATE employee
set phone_number=trim(phone_number);

-- number of employees in each town.
select 
town_name,
count(town_name) as num_employees
from employee
group by town_name;

-- get the employee_ids and use those to get the names, email and 
-- phone numbers of the three field surveyors with the most location visits
select assigned_employee_id,
count(record_id) as number_of_visits
from visits
group by assigned_employee_id
order by number_of_visits desc
limit 3;

select
employee_name,
email,
phone_number
from employee
where assigned_employee_id=1 or assigned_employee_id=30 or assigned_employee_id=34;

-- ANALYSING LOCATIONS
-- Create a query that counts the number of records per town
select 
town_name, count(*) as records_per_town
from location
group by town_name
order by records_per_town desc ;
-- the records per province.
select
province_name,
count(*) as records_per_province
from location
group by province_name
order by records_per_province desc;

select
province_name,
town_name,
count(*) as records_per_town
from location
group by province_name,
town_name
order by province_name,
records_per_town desc;
-- These results show us that our field surveyors did an excellent job of documenting the status of our country's water crisis. 
-- Every province and town has many documented sources.
select
count(*) as num_sources,
location_type
from location
group by location_type;

SELECT 23740 / (15910 + 23740) * 100;
-- From the above analysis;
-- 1. Our entire country was properly canvassed, and our dataset represents the situation on the ground.
-- 2. 60% of our water sources are in rural communities across Maji Ndogo. We need to keep this in mind when we make decisions.

-- DIVING INTO THE WATER SOURCES
-- number of people served
SELECT
sum(number_of_people_served) as total_number
from water_source;
-- number of each type of water source
select
type_of_water_source,
count(type_of_water_source) as num_sources
from water_source
group by type_of_water_source
order by num_sources desc;
-- average number of people served per particular water source
select 
distinct type_of_water_source,
ROUND(AVG(number_of_people_served) OVER (partition by type_of_water_source)) as ave_people_per_source
from water_source;
-- each household actually has its own tap. In addition to this, there is an average of
-- 6 people living in a home. So 6 people actually share 1 tap (not 644).
-- How many people are getting water from each type of source?
-- This means that 1 tap_in_home actually represents 644 ÷ 6 = ± 100 taps.
-- the total number of people served by each type of water source in total,
SELECT
distinct type_of_water_source,
sum(number_of_people_served) over (partition by type_of_water_source) as population_served
from water_source
order by population_served desc;

-- calculate percentages
SELECT
type_of_water_source,
round(sum(number_of_people_served)/(select sum(number_of_people_served) from water_source )* 100) as percentage_people_per_source
from water_source
group by type_of_water_source
order by percentage_people_per_source desc;
-- 43% of our people are using shared taps in their communities,
-- 31% of people have water infrastructure installed in their homes, but 45%
-- (14/31) of these taps are not working! This isn't the tap itself that is broken, but rather the infrastructure like treatment plants, 
-- reservoirs, pipes, and pumps that serve these homes that are broken.

-- START OF A SOLUTION
-- total people served column, converting it into a rank.
SELECT
distinct type_of_water_source,
sum(number_of_people_served) as population_served,
rank() over(order by sum(number_of_people_served) desc ) as rank_by_population
from water_source
group by type_of_water_source
order by population_served desc;
-- we should fix shared taps first, then wells, and so on.
-- which shared taps or wells should be fixed first?
SELECT *,
RANK() OVER(ORDER BY number_of_people_served desc) as priority_rank
from water_source
where type_of_water_source='well'
or type_of_water_source='shared_tap'
or type_of_water_source='river';

-- Analysing queues
-- To calculate how long the survey took, we need to get the first and last dates 
-- (which functions can find the largest/smallest value), and subtract them.
SELECT DATEDIFF(MAX(DATE(time_of_record)), MIN(DATE(time_of_record))) AS day_difference
FROM visits;
-- how long people have to queue on average
SELECT round(AVG(NULLIF(time_in_queue, 0)))AS average_queue_time
from visits;
-- the average queue time is 120 minutes approximately 2 hours.
-- So let's look at the queue times aggregated across the different days of the week.
SELECT
dayname(time_of_record) as day_of_week,
round(AVG(NULLIF(time_in_queue, 0)))AS average_queue_time
from visits
group by dayname(time_of_record);
-- We can also look at what time during the day people collect water.
select
hour(time_of_record) as hour_of_day,
round(AVG(NULLIF(time_in_queue, 0)))AS average_queue_time
from visits
group by hour(time_of_record)
order by hour(time_of_record) asc;
-- time formatting
select
time_format(time(time_of_record), '%H:00') as hour_of_day,
round(avg(nullif(time_in_queue,0))) as average_time_in_queue
from visits
group by hour_of_day
order by hour_of_day asc;
-- break down the queue times for each hour of each day
-- To filter a row we use WHERE, but using CASE() in SELECT can filter columns. We can use a CASE() function for each day to separate the queue
-- time column into a column for each day.
select
time_format(time(time_of_record), '%H:00') as hour_of_day,
-- Sunday
ROUND(AVG( -- calculates the average queue time for visits that occurred on Sundays
CASE
WHEN DAYNAME(time_of_record) = 'Sunday' THEN time_in_queue
ELSE NULL
END
),0) AS Sunday,
-- Monday
round(avg(
case
when dayname(time_of_record)='Monday' then time_in_queue
else null
end
),0) as Monday,
-- Tuesday
round(avg(
case
when dayname(time_of_record)='Tuesday' then time_in_queue
else null
end
),0) as Tuesday,
-- Wed
round(avg(
case
when dayname(time_of_record)='Wednesday' then time_in_queue
else null
end
),0) as Wednesday,
-- Thur
round(avg(
case
when dayname(time_of_record)='Thursday' then time_in_queue
else null
end
),0) as Thursday,
-- Fri
round(avg(
case
when dayname(time_of_record)='Friday' then time_in_queue
else null
end
),0) as Friday,
-- Sat
round(avg(
case 
when dayname(time_of_record)='Saturday' then time_in_queue
else null
end
),0) as Saturday
from visits
group by hour_of_day
order by hour_of_day; 
-- the above case statements return a pivot table showing the time in queue for each day at each hour
