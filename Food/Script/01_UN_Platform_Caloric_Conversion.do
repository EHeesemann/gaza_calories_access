
import excel "Commodities Received.xlsx", sheet("Suppy Page") firstrow clear
generate month=month(ReceivedDate) 
generate day=day(ReceivedDate) 
generate year=year(ReceivedDate)

order year month day
sort year month day

keep if CargoCategory == "Food Items" | CargoCategory == "Mixed Items"

drop if year == 2025
drop R- Y
save "UN_21_OCT_2023_31_DECEMBER_2024.dta", replace

u "UN_21_OCT_2023_31_DECEMBER_2024.dta", clear
set seed 12345

ren ReceivedDate date_var
ren DonatingCountryOrganization donors
format %20s donors

ren DestinationRecipientPartner recipients
format %20s recipients

keep if CargoCategory == "Food Items"

* --- 1. Normalize text to lowercase ---
gen strL items_raw = lower(DescriptionofCargo)

* Replace common separators with "+"
replace items_raw = ustrregexra(items_raw, "[,;/|&]", "+")
replace items_raw = subinstr(items_raw, " and ", "+", .)

* --- 2. Split strings into separate tokens ---
split items_raw, parse("+") gen(tok)
forvalues k = 1/50 {
    capture confirm variable tok`k'
    if !_rc replace tok`k' = strtrim(tok`k')
}

* Each group coming from the split could be saved in sub dta and then worked separately to find the caloric conversion. In this script each separate tokens has a specific dta

merge m:m tok1 using "calories_tok1.dta"

drop if _m == 2

replace kcal_tok1 = 5500 if _m == 1

* Long names are not split correclty, so needed to rework manually

drop _m
replace kcal_tok1 = 5500 if tok2 == "sq lipid nut. suppl. sml 20g"
replace tok2 = "" if tok2 == "sq lipid nut. suppl. sml 20g"
*tok1: biscuit high energy protein	car	200x50g so car is a wrong split from a misspelled item
replace tok3 ="" if tok2 == "car"
replace tok2 ="" if tok2 == "car"
replace tok2 = "" if tok2 == "based nutrient supplement (lns)"
replace tok2 = "" if tok2 == "based nutrition supplements (lns)"
replace tok2 = "" if tok2 == "lns"
replace tok3 = "" if tok2 =="to"
replace tok2 = "" if tok2 == "to"

replace kcal_tok1 = 3300 if tok1 == "legumes"
replace kcal_tok1 = 150 if tok1 == "lattice"
replace kcal_tok1 = 1010 if tok1 == "ketchup"
replace kcal_tok1 = 460 if tok1 == "juices"
replace kcal_tok1 = 430 if tok1 == "jute leaves"
replace tok3 = "" if tok1 == "lns" & tok3 == "car"
replace tok3 = "" if tok3 == "based nutrient supplement (lns)"
replace tok4 = "" if tok3 == "to" & tok2 == "ready"
replace tok3 = "" if tok3 == "to" & tok2 == "ready"
replace tok4 = "" if tok4 == "600"


merge m:m tok2 using "calories_tok2.dta"
drop if _m == 2
drop _m

merge m:m tok3 using "calories_tok3.dta"
drop if _m == 2
drop _m

merge m:m tok4 using "calories_tok4.dta"
drop if _m == 2
drop _m

merge m:m tok5 using "calories_tok5.dta"
drop if _m == 2
drop _m

replace kcal_tok2 = 4500 if tok6 == "car"
replace tok6 = "" if tok6 == "car"

merge m:m tok6 using "calories_tok6.dta"
drop if _m == 2
drop _m

replace kcal_tok5=. if tok7 == "200x50g"
replace tok7 ="" if tok7 == "200x50g"

merge m:m tok7 using "calories_tok7.dta"
drop if _m == 2
drop _m

g kcal_tok8 = 0 if tok8 == "salt"
replace kcal_tok8 =960 if tok8 == "canned corn"
replace kcal_tok8 = 8840 if tok8 == "oil"

g kcal_tok9 = 3530 if tok9 == "lentils"
replace kcal_tok9 = 640 if tok9 == "milk"
gen kcal_tok10 = 820 if tok10 == "tomato paste"

foreach var of varlist kcal_tok1- kcal_tok10 {
	gen t_`var' = 1 if `var'!=.
	replace t_`var' = 0 if t_`var'==.
	}

	foreach var of varlist tok1- tok10 {
	replace kcal_`var' = 0 if `var'== "yeast"
	}
	
egen mixed =rowtotal( t_kcal_tok1- t_kcal_tok10)
g truck_food = 1/ mixed

encode Manifestof,gen(manifest)
* Create category = 1 if contains "Manifest " but not "Non-Manifest"
gen byte manifest_cat = strpos(Manifestof, "Manifest ") > 0 ///
                        & strpos(Manifestof, "Non- Manifest") == 0

replace manifest_cat = 0 if regexm(Manifestof, "^(Non-Manifest)")
replace manifest_cat = 0 if regexm(Manifestof, "^( Non[[:space:]]+Manifest )")
replace manifest_cat = 0 if manifest == 42
replace manifest_cat = 2 if manifest == .

label def manifest_cat 1 "Manifest" 0 "Non-Manifest" 2 "No-info"
label value manifest_cat manifest_cat

* OUTLIER DETECTED - PROBABLY A MISTAKE IN THE REPORTING
replace Quantity = 14 if Quantity == 144

g standard_weight = 20

g pallets_weight = 0.750
replace Unit = "N/A" if Unit == ""
g truck_weight = pallets_weight*Quantity if Units == "Pallets"

replace truck_weight = 18.4 if  DescriptionofCargo == "Eggs" & Units == "CTN"
replace truck_weight = 20 if  DescriptionofCargo == "Frozen Meat" & Units == "CTN"
replace truck_weight = 20 if  DescriptionofCargo == "Frozen Vegetables + Frozen Meat" & Units == "Piece"
replace truck_weight = 20 if  DescriptionofCargo == "Frozen Meat" & Units == "Piece"

replace truck_weight = 20 if  DescriptionofCargo=="Livestock" & Units=="Piece"

replace truck_weight = Quantity if Units == "MT" | Units == "Ton"
replace truck_weight = 20 if Units == "Truck"
replace truck_weight = 20 if Quantity == 1 & Units == "N/A"
replace truck_weight = Quantity if Units == "N/A" & truck_weight == .
replace truck_weight = 20 if Quantity == 0 & truck_weight == 0

* WITHOUT LOSS in TRUCKS

foreach var of varlist kcal_tok1- kcal_tok10 {
	gen cal_t_`var' = ((truck_weight*truck_food)*1000)*`var'
	}
	*  PALLETS
egen calories_tot =rowtotal( cal_t_kcal_tok1- cal_t_kcal_tok10)

foreach var of varlist kcal_tok1- kcal_tok10 {
	gen standard_cal_t_`var' = ((standard_weight*truck_food)*1000)*`var'
	}
* 20MT
egen standard_calories_tot =rowtotal(standard_cal_t_kcal_tok1- standard_cal_t_kcal_tok10)	


preserve
sa "UN_data_donation_agency.dta",replace
restore
*/
*preserve 
collapse(sum) truck_food NoofTrucks truck_weight standard_weight calories_tot standard_calories_tot  ,by(year month day  Status Crossing date_var)
gen n_trucks = NoofTrucks
gen MT = truck_weight

g truck_capacity = MT/n_trucks

qui tab Crossing,gen(dum)

* 0) Treat missings as zeros so 0×. becomes 0 (not .)
foreach v in n_trucks MT standard_weight {
    capture confirm variable `v'
    if !_rc gen `v'_z = cond(missing(`v'), 0, `v')
}
* FURTHER ANALYSIS BY ENTRY POINTS IS POSSIBLE
local crosses "erez gate96 jlots kerem_shalom kissufim rafah western_erez"

* 2) Generate multiplied variables for each dummy
forvalues i = 1/7 {
    local nm : word `i' of `crosses'

    * Trucks
    gen trucks_`nm' = n_trucks_z * dum`i'

    * Metric tons
    gen mt_`nm' = MT_z * dum`i'

    * Standard weight
    gen stdwt_`nm' = standard_weight_z * dum`i'
}

* Optional: sanity check
egen dsum = rowtotal(dum1-dum7)
assert inlist(dsum, 0, 1)
drop dsum

collapse(sum) trucks_erez mt_erez trucks_gate96 mt_gate96 trucks_jlots mt_jlots trucks_kerem_shalom mt_kerem_shalom trucks_kissufim mt_kissufim trucks_rafah mt_rafah trucks_western_erez mt_western_erez stdwt_erez stdwt_gate96 stdwt_jlots stdwt_kerem_shalom stdwt_kissufim stdwt_rafah stdwt_western_erez calories_tot standard_calories_tot ,by(year month day date_var)
sort year month day
merge 1:1 date_var using "data_airdrops_MT.dta"
drop _m

foreach v in trucks_erez mt_erez trucks_gate96 mt_gate96 ///
             trucks_jlots mt_jlots trucks_kissufim mt_kissufim ///
             trucks_rafah mt_rafah  {
    cap confirm variable `v'
    if !_rc rename `v' `=upper("`v'")'
}

ren trucks_kerem_shalom TRUCKS_KS
ren mt_kerem_shalom MT_KS
ren trucks_western_erez TRUCK_WE
ren mt_western_erez MT_WE

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

tempfile UN
sa `UN', replace

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
use `UN', clear
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

keep if date_var<=td(30sep2025)

sort date_var
replace year = 2024 if year == .
replace month = 5 if month == .
replace day = 7 if date_var == 23503
replace day = 9 if date_var == 23505

ren mt_airdrop MT_airdrops
replace MT_airdrops = . if MT_airdrops == 0

*Assumption: Average energy density of airdropped food = 3,300 kcal/kg
/*Reason: Based on typical composition of humanitarian food parcels (≈ 55% flour, 15% canned food, 10% cereals, 10% oils, 5% sweet foods, 5% condiments/dairy) and weighted using NutVal and WFP food composition tables.*/

scalar cal_3300 = 3300 

egen total_truck_land = rowtotal( TRUCKS_EREZ TRUCKS_GATE96 TRUCKS_KS TRUCKS_KISSUFIM TRUCKS_RAFAH TRUCK_WE)

label variable TRUCKS_EREZ "Trucks entered through EREZ"
label variable MT_EREZ "MT entered through EREZ"
label variable TRUCKS_GATE96 "Trucks entered through Gate 96"
label variable MT_GATE96 "MT entered through Gate 96"
label variable TRUCKS_JLOTS "Trucks entered through JLOTS"
label variable MT_JLOTS "MT entered though JLOT"
label variable TRUCKS_KS "Truck entered through KS"
label variable MT_KS "MT entered through Kerem Shalom"
label variable TRUCKS_KISSUFIM "Trucks entered through Kissufim"
label variable MT_KISSUFIM "MT entered through Kissufim"
label variable TRUCKS_RAFAH "Trucks entered through Rafah"
label variable MT_RAFAH "MT entered through Rafah"
label variable TRUCK_WE "Trucks entered through Western Erez"
label variable MT_WE "MT entered through Western Erez"

label variable stdwt_erez "MT (20 MT) entered through EREZ"
label variable stdwt_gate96 "MT (20 MT) entered through Gate 96"
label variable stdwt_jlots "MT (20 MT) entered though JLOT"
label variable stdwt_kerem_shalom "MT (20 MT) entered through KS"
label variable stdwt_kissufim "MT (20 MT) entered through Kissufim"
label variable stdwt_rafah "MT (20 MT) entered through Rafah"
label variable stdwt_western_erez "MT (20 MT) entered through Western Erez"

egen MT_land = rowtotal(MT_EREZ MT_GATE96 MT_KS MT_KISSUFIM MT_RAFAH MT_WE)
egen standard_MT_land = rowtotal(stdwt_erez stdwt_gate96 stdwt_kerem_shalom stdwt_kissufim stdwt_rafah stdwt_western_erez)

drop  TRUCKS_EREZ TRUCKS_GATE96 TRUCKS_KS TRUCKS_JLOTS

ren total_truck_land N_TRUCKS

ren MT_land MT_PALLETS
ren standard_MT_land MT_20MT

gen calories_AIRDROPS = MT_airdrops*1000*cal_3300
format %15.0g calories_AIRDROPS

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

foreach var of varlist calories_tot standard_calories_tot calories_AIRDROPS calories_internal_production {
	format %15.0g `var'
 
}
drop MT_EREZ- stdwt_western_erez
ren calories_tot calories_imp_pallets
ren standard_calories_tot calories_imp_20MT
 
sa "UN_PLATFORM_CALORIES_21_OCT_2023_31_DECEMBER_2024.dta", replace