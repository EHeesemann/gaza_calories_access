clear all
set more off

***************************************************************
* NOLOSS
***************************************************************

u "UN_PLATFORM_CALORIES_21_OCT_2023_31_DECEMBER_2024.dta", clear
set seed 12345

preserve
import excel "stock_pre_war.xlsx", sheet("stock pre war") firstrow clear
format %15.0g tot_cal_pre_stock
tempfile pre
sa `pre'
restore

merge 1:1 date_var using  `pre'
drop _m

gen pc_prewar = tot_cal_pre_stock/population
keep date_var day month year calories_imp_pallets days_in_month population calories_internal_production tot_cal_pre_stock calories_AIRDROPS
order date_var day month year days_in_month population

g tot_c_bis = calories_imp_pallets /*After running the NO LOSS you can rerun the same script for 5% and 15% respectively, adding the loss to calories_imp_pallets*/ 

egen b = rowtotal(calories_internal_production tot_cal_pre_stock tot_c_bis )

gen double kcal_pc = b/ population 
gen ym    = ym(year, month)
format ym %tmMonYY
label var ym "Monthly date"

***************************************************************
* Verification: daily observations per month
***************************************************************
preserve
collapse (count) n_days = kcal_pc, by(ym)
gen year  = year(dofm(ym))
gen month = month(dofm(ym))
order year month n_days
list year month n_days, sepby(year)
restore

***************************************************************
* bootstrap
***************************************************************
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

save "monthly_caloriesavailability_BOOTSTRAP_FIXED_PALLETS_NOLOSS.dta", replace
*You can save here the data according to the loss (No loss, 5% loss, 15% loss)