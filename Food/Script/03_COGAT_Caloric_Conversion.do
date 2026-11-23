**************************************************************************************
* COGAT DATA ON FOOD ENTERING FROM OCT 2023 and DECEMBER 2024                       *
**************************************************************************************
import delimited "data fromCOGAT WEBSITE.csv", clear


encode route, gen(route1)
drop route
ren route1 route
order date classification route
encode classification,gen(type)
drop classification
order date type route

keep if type == 2
generate date_var = date( date , "DM20Y")
format date_var %td

generate day = day(date_var)
generate month = month(date_var)
generate year = year(date_var)
order date_var day month year
drop date

replace aidtons = "" if aid == "-"
destring aidtons, replace
rename aidtons mt_food


encode donatingorganisationcategory,gen(humanitarian_donor)
tab humanitarian_donor
g mt_airdrop = mt if route == 1
drop donatingorganisationcategory
order date_var- route humanitarian_donor

replace mt_food = 0 if mt_airdrop!=.

g airdrop_load = trucks if route == 1
replace trucks = 0 if mt_airdrop!=.
generate days_in_month = daysinmonth(date_var)

order date_var day month year days_in_month

g mt_food_un = mt_food if humanitarian_donor == 5
g truck_un = trucks  if humanitarian_donor == 5

g mt_food_ngo = mt_food if humanitarian_donor == 2
g truck_ngo = trucks  if humanitarian_donor == 2

g mt_food_country_mixed_d = mt_food if humanitarian_donor == 1 | humanitarian_donor == 3
g truck_country_mixed_d = trucks  if humanitarian_donor == 1 | humanitarian_donor == 3

g mt_food_private_sector = mt_food if humanitarian_donor == 4
g truck_private_sector = trucks  if humanitarian_donor == 4

collapse(sum) mt_food mt_airdrop airdrop_load mt_food_un truck_un mt_food_ngo truck_ngo mt_food_country_mixed_d truck_country_mixed_d mt_food_private_sector truck_private_sector,by( date_var day month year)

* we apply the calories for kg as calculated in the UN platform dataset - from Donors conversion factor
scalar un=3020
scalar ngos = 2283
scalar oth = 2283
scalar priv_sector = 2344
scalar airdrop = 3300
scalar ghf = 3234
*ren mt_food_ngo NGO_mt

g cal_un = mt_food_un*1000*un
format %15.0g cal_un

* ACCOUNTING FOR GHF FOOD DISTRIBUTION
g GHF_mt = mt_food_ngo*0.53 if date_var>= td(27may2025) & date_var<= td(31may2025) 
replace GHF_mt = mt_food_ngo*0.80 if date_var>= td(01jun2025) & date_var<= td(30jun2025) 
replace GHF_mt = mt_food_ngo*0.64 if date_var>= td(01jul2025) & date_var<= td(31jul2025) 
replace GHF_mt = mt_food_ngo*0.46 if date_var>= td(01aug2025) & date_var<= td(31aug2025) 
replace GHF_mt = mt_food_ngo*0.39 if date_var>= td(01sep2025) & date_var<= td(30sep2025) 

g NGO_mt = mt_food_ngo*0.47 if date_var>= td(27may2025) & date_var<= td(31may2025) 
replace NGO_mt = mt_food_ngo*0.20 if date_var>= td(01jun2025) & date_var<= td(30jun2025) 
replace NGO_mt = mt_food_ngo*0.36 if date_var>= td(01jul2025) & date_var<= td(31jul2025) 
replace NGO_mt = mt_food_ngo*0.54 if date_var>= td(01aug2025) & date_var<= td(31aug2025) 
replace NGO_mt = mt_food_ngo*0.61 if date_var>= td(01sep2025) & date_var<= td(30sep2025) 
replace NGO_mt = mt_food_ngo if date_var<= td(26may2025) 

* GET CALORIES CONVERSION
gen calories_ghf = GHF_mt*1000*ghf
gen calories_ngo = NGO_mt*1000*ngos
egen calories_NGO = rowtotal(calories_ghf calories_ngo)
drop calories_ghf calories_ngo
rename calories_NGO cal_ngo
format %15.0g cal_ngo

g cal_countries = (mt_food_country_mixed_d*1000)*oth
format %15.0g cal_countries

g cal_priv_sector= mt_food_private_sector*1000*priv_sector
format %15.0g cal_priv_sector

g cal_airdrop = mt_airdrop*1000*airdrop
format %15.0g cal_airdrop

egen tot_c = rowtotal(cal_un cal_ngo cal_priv_sector cal_airdrop cal_countries)
format %15.0g tot_c

keep if date_var<=td(30sep2025)

* Check if there are missing days in the temporal series
* Sort by date
sort date_var

* Generate difference between consecutive days
gen day_gap = date_var - date_var[_n-1]

* List cases where the gap is bigger than 1
list date_var day_gap if day_gap > 1

* Quick summary: number of missing days
count if day_gap > 1

* === STEP 2: Create a full sequence of days ===
summarize date_var
local dmin = r(min)
local dmax = r(max)

tempfile COGAT
sa `COGAT', replace

summarize date_var
local dmin = r(min)
local dmax = r(max)

clear
set obs `= `dmax' - `dmin' + 1'
gen date_var = `dmin' + _n - 1
format date_var %td

tempfile alldays
save `alldays'


* === STEP 3: Merge back with original dataset ===
use `COGAT', clear
merge 1:1 date_var using `alldays'
drop day month year

generate day = day(date_var)
generate month = month(date_var)
generate year = year(date_var)
order date_var day month year
sort date_var
drop _merge

drop day_gap
generate days_in_month = daysinmonth(date_var)

collapse(sum) mt_airdrop- tot_c days_in_month,by( date_var day month year)

g population =  2289696.19500000000 if inrange(date_var, td(21oct2023), td(31oct2023))
replace population = 2273871.69216661000 if inrange(date_var, td(01nov2023), td(30nov2023))
replace population = 2258156.55532267000 if inrange(date_var, td(01dec2023), td(31dec2023))
replace population = 2242550.02862014000 if inrange(date_var, td(01jan2024), td(31jan2024))
replace population = 2227051.36143476000 if inrange(date_var, td(01feb2024), td(29feb2024))
replace population = 2211659.80832999000 if inrange(date_var, td(01mar2024), td(31mar2024))
replace population = 2196374.62902111000 if inrange(date_var, td(01apr2024), td(30apr2024))
replace population = 2181195.08833967000 if inrange(date_var, td(01may2024), td(31may2024))
replace population = 2166120.45619809000 if inrange(date_var, td(01jun2024), td(30jun2024))
replace population = 2151150.00755454000 if inrange(date_var, td(01jul2024), td(31jul2024))
replace population = 2136283.02237810000 if inrange(date_var, td(01aug2024), td(31aug2024))
replace population = 2121518.78561413000 if inrange(date_var, td(01sep2024), td(30sep2024))
replace population = 2106856.58714982000 if inrange(date_var, td(01oct2024), td(31oct2024))
replace population = 2092295.72178012000 if inrange(date_var, td(01nov2024), td(30nov2024))
replace population = 2077835.48917376000 if inrange(date_var, td(01dec2024), td(31dec2024))
replace population = 2063015.86507594000 if inrange(date_var, td(01jan2025), td(31jan2025))
replace population = 2048301.93811322000 if inrange(date_var, td(01feb2025), td(28feb2025))
replace population = 2033692.95442813030 if inrange(date_var, td(01mar2025), td(31mar2025))
replace population = 2019188.16553987000 if inrange(date_var, td(01apr2025), td(30apr2025))
replace population = 2004786.82830602000 if inrange(date_var, td(01may2025), td(31may2025))
replace population = 1990488.20488441000 if inrange(date_var, td(01jun2025), td(30jun2025))
replace population = 1976291.56269536000 if inrange(date_var, td(01jul2025), td(31jul2025))
replace population = 1960812.7702902100 if inrange(date_var, td(01aug2025), td(31aug2025))
replace population = 1945455.2115222600 if inrange(date_var, td(01sep2025), td(30sep2025))

g calories_internal_production =  population*220.72 if inrange(date_var, td(21oct2023), td(31oct2023))
replace calories_internal_production = population*201.14 if inrange(date_var, td(01nov2023), td(30nov2023))
replace calories_internal_production = population*120.78 if inrange(date_var, td(01dec2023), td(31dec2023))
replace calories_internal_production = population*109.27 if inrange(date_var, td(01jan2024), td(31jan2024))
replace calories_internal_production = population*98.88 if inrange(date_var, td(01feb2024), td(29feb2024))
replace calories_internal_production = population*92.16 if inrange(date_var, td(01mar2024), td(31mar2024))
replace calories_internal_production = population*85.91 if inrange(date_var, td(01apr2024), td(30apr2024))
replace calories_internal_production = population*80.09 if inrange(date_var, td(01may2024), td(31may2024))
replace calories_internal_production = population*76.17 if inrange(date_var, td(01jun2024), td(30jun2024))
replace calories_internal_production = population*72.48 if inrange(date_var, td(01jul2024), td(31jul2024))
replace calories_internal_production = population*69.00 if inrange(date_var, td(01aug2024), td(31aug2024))
replace calories_internal_production = population*57.43 if inrange(date_var, td(01sep2024), td(30sep2024))
replace calories_internal_production = population*54.85 if inrange(date_var, td(01oct2024), td(31oct2024))
replace calories_internal_production = population*52.42 if inrange(date_var, td(01nov2024), td(30nov2024))
replace calories_internal_production = population*50.13 if inrange(date_var, td(01dec2024), td(31dec2024))
replace calories_internal_production = population*48  if inrange(date_var, td(01jan2025), td(31jan2025))
replace calories_internal_production = population*46  if inrange(date_var, td(01feb2025), td(28feb2025))
replace calories_internal_production = population*33 if inrange(date_var, td(01mar2025), td(31mar2025))
replace calories_internal_production = population*32 if inrange(date_var, td(01apr2025), td(30apr2025))
replace calories_internal_production = population*31 if inrange(date_var, td(01may2025), td(31may2025))
replace calories_internal_production = population*31 if inrange(date_var, td(01jun2025), td(30jun2025))
replace calories_internal_production = population*31 if inrange(date_var, td(01jul2025), td(31jul2025))
replace calories_internal_production = population*31 if inrange(date_var, td(01aug2025), td(31aug2025))
replace calories_internal_production = population*31 if inrange(date_var, td(01sep2025), td(30sep2025))
format %15.0g calories_internal_production
egen tot_cal = rowtotal(tot_c calories_internal_production)
format %15.0g tot_cal
save "COGAT_CALORIES_21_OCT_2023_30_SEPTEMBER_2025.dta", replace