clear all
set more off

***************************************************************
* Load dataset - NOLOSS
***************************************************************
import excel "COGAT_DATA_OCT_2023_SEPTEMBER_2025.xlsx", sheet("COGAT DATA") firstrow clear
ren INTERNALPRODUCTIONTOTALCALORI calories_internal_production
ren PREWARSTOCKTOTALCALORIES tot_cal_pre_stock
ren IMPORTATIONTOTALCALORIES tot_c
ren POPULATION population

g tot_c_bis = tot_c /*After running the NO LOSS you can rerun the same script for 5% and 15% respectively, adding the loss to tot_c*/ 
egen b = rowtotal(calories_internal_production tot_cal_pre_stock tot_c_bis)
gen double kcal_pc = b/ population 
generate day = day(date_var)
generate month = month(date_var)
generate year = year(date_var)
gen ym    = ym(year, month)
format ym %tmMonYY
label var ym "Monthly date"

preserve
collapse (count) n_days = kcal_pc, by(ym)
gen year  = year(dofm(ym))
gen month = month(dofm(ym))
order year month n_days
list year month n_days, sepby(year)
restore

capture program drop meanprog
program define meanprog, rclass
    summarize kcal_pc, meanonly
    return scalar mean = r(mean)
end

tempname results
tempfile resfile
postfile `results' ym mean_kcal_pc ci_lower ci_upper using `resfile', replace

levelsof ym, local(months)
local totalmonths : word count `months'
local counter = 0

foreach m of local months {
    local ++counter

    preserve
    keep if ym == `m'

    if _N < 5 {
        quietly summarize kcal_pc, meanonly
        post `results' (`m') (r(mean)) (. ) (. )
        restore
        continue
    }

    quietly bootstrap r(mean), reps(100) seed(12345) nodots: meanprog

    quietly ci mean kcal_pc
    local mean = r(mean)
	local ll = r(lb)
	local ul = r(ub)

    post `results' (`m') (`mean') (`ll') (`ul')

    restore
}
postclose `results'

use `resfile', clear
sort ym
gen year  = year(dofm(ym))
gen month = month(dofm(ym))
order year month mean_kcal_pc ci_lower ci_upper
format ym %tmMonYY
save "monthly_caloriesavailability_BOOTSTRAP_FIXED_COGAT_NOLOSS.dta", replace
* files for 5% and 15% loss can be also saved