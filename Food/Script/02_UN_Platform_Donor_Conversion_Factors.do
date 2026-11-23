* CALORIES PER KG CONVERSION 

u "UN_data_donation_agency.dta", clear
tab hum_agency

collapse(sum) truck_food NoofTrucks truck_weight standard_weight calories_tot standard_calories_tot,by(year month day hum_agency  date_var)
gen n_trucks = NoofTrucks
gen MT = truck_weight

qui tab hum_agency,gen(dum)

* 0) Treat missings as zeros so 0×. becomes 0 (not .)
foreach v in n_trucks MT standard_weight calories_tot standard_calories_tot{
    capture confirm variable `v'
    if !_rc gen `v'_z = cond(missing(`v'), 0, `v')
}

local agencies "ingo other pcrs un priv_sector"

forvalues i = 1/5 {
    local nm : word `i' of `agencies'

    * Trucks
    gen trucks_`nm' = n_trucks_z * dum`i'

    * Metric tons
    gen mt_`nm' = MT_z * dum`i'

    * Standard weight
    gen stdwt_`nm' = standard_weight_z * dum`i'
	
	* Calories MT
	gen cal_`nm' = calories_tot_z* dum`i'
	
	* Calories standard MT
	gen std_cal_tot_`nm' = standard_calories_tot_z* dum`i'
}



collapse(sum) trucks_ingo mt_ingo stdwt_ingo cal_ingo std_cal_tot_ingo trucks_other mt_other stdwt_other cal_other std_cal_tot_other trucks_pcrs mt_pcrs stdwt_pcrs cal_pcrs std_cal_tot_pcrs trucks_un mt_un stdwt_un cal_un std_cal_tot_un trucks_priv_sector mt_priv_sector stdwt_priv_sector cal_priv_sector std_cal_tot_priv_sector,by( year month day date_var)

merge 1:1 date_var using "data_airdrops.dta"
drop _m

gen cal_airdrop = 3300

g tot_cal_airdrops = ((MT_airdrops)*1000)*cal_airdrop

preserve
tempfile missdates
clear

* 1) Enter the missing dates as strings
input str10 date_str
"25oct2023"
"28oct2023"
"15nov2023"
"17nov2023"
"01dec2023"
"27jan2024"
"03feb2024"
"10feb2024"
"10may2024"
"24aug2024"
"05oct2024"
"07oct2024"
"11oct2024"
"12oct2024"
"21dec2024"
"28dec2024"
end

* 2) Convert to numeric daily dates to match master
gen double date_var = date(date_str, "DMY")
format %td date_var
drop date_str

* (optional) match storage type of master if it's float
recast float date_var

save `missdates', replace
restore

* 3) Append the numeric dates
append using `missdates'

* Assuming your numeric daily date variable is called date_var
replace year  = year(date_var)  if missing(year)
replace month = month(date_var) if missing(month)
replace day   = day(date_var)   if missing(day)

sort date_var

collapse(sum) trucks_ingo mt_ingo stdwt_ingo cal_ingo std_cal_tot_ingo trucks_other mt_other stdwt_other cal_other std_cal_tot_other trucks_pcrs mt_pcrs stdwt_pcrs cal_pcrs std_cal_tot_pcrs trucks_un mt_un stdwt_un cal_un std_cal_tot_un trucks_priv_sector mt_priv_sector stdwt_priv_sector cal_priv_sector std_cal_tot_priv_sector,by( year month day date_var)
tempfile FOOD_DAILY
sa  `FOOD_DAILY', replace

collapse(sum) trucks_ingo mt_ingo stdwt_ingo cal_ingo std_cal_tot_ingo trucks_other mt_other stdwt_other cal_other std_cal_tot_other trucks_pcrs mt_pcrs stdwt_pcrs cal_pcrs std_cal_tot_pcrs trucks_un mt_un stdwt_un cal_un std_cal_tot_un trucks_priv_sector mt_priv_sector stdwt_priv_sector cal_priv_sector std_cal_tot_priv_sector,by( year month)
tempfile FOOD_MONTHLY

g population =  2289696.19500000000 if year == 2023 & month == 10
replace population = 2273871.69216661000 if year == 2023 & month == 11
replace population = 2258156.55532267000 if year == 2023 & month == 12
replace population = 2242550.02862014000 if year == 2024 & month == 1
replace population = 2227051.36143476000 if year == 2024 & month == 2
replace population = 2211659.80832999000 if year == 2024 & month == 3
replace population = 2196374.62902111000 if year == 2024 & month == 4
replace population = 2181195.08833967000 if year == 2024 & month == 5
replace population = 2166120.45619809000 if year == 2024 & month == 6
replace population = 2151150.00755454000 if year == 2024 & month == 7
replace population = 2136283.02237810000 if year == 2024 & month == 8
replace population = 2121518.78561413000 if year == 2024 & month == 9
replace population = 2106856.58714982000 if year == 2024 & month == 10
replace population = 2092295.72178012000 if year == 2024 & month == 11
replace population = 2077835.48917376000 if year == 2024 & month == 12
recode trucks_ingo- std_cal_tot_priv_sector (0 = .)
sa  `FOOD_MONTHLY', replace

collapse(sum) trucks_ingo mt_ingo stdwt_ingo cal_ingo std_cal_tot_ingo trucks_other mt_other stdwt_other cal_other std_cal_tot_other trucks_pcrs mt_pcrs stdwt_pcrs cal_pcrs std_cal_tot_pcrs trucks_un mt_un stdwt_un cal_un std_cal_tot_un trucks_priv_sector mt_priv_sector stdwt_priv_sector cal_priv_sector std_cal_tot_priv_sector,by( year)
tempfile FOOD_YEAR
recode trucks_ingo- std_cal_tot_priv_sector (0 = .)
sa  `FOOD_YEAR', replace

collapse(sum) trucks_ingo mt_ingo stdwt_ingo cal_ingo std_cal_tot_ingo trucks_other mt_other stdwt_other cal_other std_cal_tot_other trucks_pcrs mt_pcrs stdwt_pcrs cal_pcrs std_cal_tot_pcrs trucks_un mt_un stdwt_un cal_un std_cal_tot_un trucks_priv_sector mt_priv_sector stdwt_priv_sector cal_priv_sector std_cal_tot_priv_sector
tempfile FOOD_TOTAL
sa  `FOOD_TOTAL', replace

g kcal_kg_UN = cal_un/( mt_un*1000)

g kcal_kg_INGOS = cal_ingo/(mt_ingo*1000)

g kcal_kg_oth = cal_other/(mt_other*1000)

g kcal_kg_priv_sec = cal_priv_sector/(mt_priv_sector*1000) 

g kcal_kg_pcrs = cal_pcrs/(mt_pcrs*1000)

g kcal_kg_UN_std = std_cal_tot_un/( stdwt_un*1000)

g kcal_kg_INGOS_std = std_cal_tot_ingo/(stdwt_ingo*1000)

g kcal_kg_oth_std = std_cal_tot_other/(stdwt_other*1000)

g kcal_kg_priv_sec_std = std_cal_tot_priv_sector/(stdwt_priv_sector*1000) 

g kcal_kg_pcrs_std = std_cal_tot_pcrs/(stdwt_pcrs*1000)
   

gen kcal_kg_country_oth = ((kcal_kg_oth*trucks_other)+(kcal_kg_pcrs*trucks_pcrs))/(trucks_other+trucks_pcrs)

g weighted_average = (( mt_ingo* kcal_kg_INGOS )+( mt_other* kcal_kg_oth )+ (mt_pcrs* kcal_kg_pcrs )+ ( kcal_kg_UN*mt_un)+( mt_priv_sector* kcal_kg_priv_sec))/( mt_ingo+ mt_other+ mt_pcrs+ mt_un+ mt_priv_sector)

g weighted_average_std = (( stdwt_ingo* kcal_kg_INGOS_std )+( stdwt_other* kcal_kg_oth_std )+ (stdwt_pcrs* kcal_kg_pcrs_std )+ ( kcal_kg_UN_std*stdwt_un)+(stdwt_priv_sector* kcal_kg_priv_sec_std))/( stdwt_ingo+ stdwt_other+ stdwt_pcrs+ stdwt_un+ stdwt_priv_sector)

egen kcal_tot_avg = rowmean(weighted_average weighted_average_std )

keep kcal_kg_UN- kcal_tot_avg

sa "conversion_factor_kcal_kg.dta", replace

