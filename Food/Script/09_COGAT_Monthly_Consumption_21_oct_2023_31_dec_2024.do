*******************************************************
*  Gaza Food Availability Simulation – MRCI 2100 for all period
*  With inter-daily stockpile carryover
*  Period: Oct 2023 – Dec 2024
*******************************************************

*******************************************************
* NO LOSS
*******************************************************
clear all
set more off
set seed 12345

* ==== SCENARIO PARAMETERS ====
scalar lambda_in  = 0.00          // we discount for loss when construting the caloric variable
scalar rho_S      = 0.000         // we need this from january 2025 so now we put equal to zero
scalar capS       = .             // unlimited storage
scalar sd         = 0.20          // allowing for SD for CI calculation especially when fod available is higher than 2100
scalar R_fixed    = 2100          // MRCI
scalar B_bs       = 1000          // bootstrap replications

* ==== MONTHS AND YEARS ====
local months "oct nov dec jan feb mar apr may jun jul aug sep oct nov dec"
local years  "2023 2023 2023 2024 2024 2024 2024 2024 2024 2024 2024 2024 2024 2024 2024"

* ==== INITIAL STOCKPILE ====
scalar S0 = 0

******************************************************************
*  MAIN MONTHLY LOOP – stockpile carried forward
******************************************************************
forvalues i = 1/15 {
    local m : word `i' of `months'
    local y : word `i' of `years'

set more off

import excel "COGAT_DATA_OCT_2023_SEPTEMBER_2025.xlsx", sheet("COGAT DATA") firstrow clear
drop if date_var == .
ren INTERNALPRODUCTIONTOTALCALORI calories_internal_production
ren PREWARSTOCKTOTALCALORIES tot_cal_pre_stock
ren IMPORTATIONTOTALCALORIES tot_c
ren POPULATION N_t

generate day = day(date_var)
generate month = month(date_var)
generate year = year(date_var) 
gen ym    = ym(year, month)
format ym %tmMonYY
label var ym "Monthly date"

keep date_var day month year tot_c days_in_month N_t calories_internal_production tot_cal

g tot_c_bis = tot_c /*multiply here by the respective by 0.95 or 0.85 when running different loss asumption*/

egen b = rowtotal(calories_internal_production tot_cal_pre_stock tot_c_bis)
gen double kcal_pc = b/ N_t
rename b K

assert !missing(N_t)

keep if inrange(date_var, td(21oct2023), td(31dec2024))


    if "`m'"=="oct" & `y'==2023 local start = td(21oct2023)
    else local start = td(01`m'`y')

    local end = .
    if "`m'"=="jan" local end = td(31jan`y')
    if "`m'"=="feb" {
        if mod(`y',4)==0 local end = td(29feb`y')
        else local end = td(28feb`y')
    }
    if "`m'"=="mar" local end = td(31mar`y')
    if "`m'"=="apr" local end = td(30apr`y')
    if "`m'"=="may" local end = td(31may`y')
    if "`m'"=="jun" local end = td(30jun`y')
    if "`m'"=="jul" local end = td(31jul`y')
    if "`m'"=="aug" local end = td(31aug`y')
    if "`m'"=="sep" local end = td(30sep`y')
    if "`m'"=="oct" local end = td(31oct`y')
    if "`m'"=="nov" local end = td(30nov`y')
    if "`m'"=="dec" local end = td(31dec`y')

    keep if inrange(date_var, `start', `end')
    count
    if r(N)==0 {
        di as err "⚠️  No data for month `m' `y' — skipping."
        continue
    }

    tempfile monthdata
    save `monthdata', replace

    tempname Hnd_bs
    postfile `Hnd_bs' mean_pc_bs mean_S_bs share_below_2100 share_above_2100 using ///
        "bs_COGAT_`m'_`y'_CARRYOVER_noloss_excel.dta", replace
    forvalues b = 1/`=scalar(B_bs)' {
        use `monthdata', clear
        sort date_var
        summarize K, meanonly
        scalar K_mean = r(mean)
        gen double relK = K / K_mean
        gen double inflow_sd = cond(relK < 0.5, 0.15, cond(relK < 1, 0.10, 0.05))
        gen double K_adj = K * (1 - lambda_in) * (1 + rnormal(-0.05, inflow_sd))
		
* === block bootstrap ===
        count
		local n_days = r(N)
		local blocklen = 7
		if "`m'" == "oct" & `y' == 2023 local blocklen = 1
		if `n_days' < `blocklen' local blocklen = `n_days'
		local nblocks = ceil(`n_days' / `blocklen')
		gen block_id = ceil(_n / `blocklen')
		tempfile bs_month
		save `bs_month', replace
		tempfile resample
		save `resample', emptyok replace
		forvalues bblock = 1/`nblocks' {
			local draw = ceil(runiform() * `nblocks')
			use `bs_month', clear
			keep if block_id == `draw'
			append using `resample'
			save `resample', replace
		}

use `resample', clear
drop block_id
sort date_var
        gen double A_i   = .
        gen double S_end = .
        gen double A_pc  = .
        local S_prev = S0   // we can put previous month carryover = 0 becasue we have an excel file with data from pre-stock
        quietly {
            forvalues j = 1/`=_N' {
                scalar S_eff = `S_prev' * (1 - rho_S)
                scalar P_i   = K_adj[`j'] + S_eff
                scalar R_need = R_fixed * N_t[`j']
                scalar A_t = min(P_i, R_need)
                scalar S_new = P_i - A_t
                if (S_new < 0) scalar S_new = 0
                if (capS < .) scalar S_new = min(S_new, capS)
                replace A_i   = A_t in `j'
                replace S_end = S_new in `j'
                replace A_pc  = A_t / N_t[`j'] in `j'
                local S_prev = S_new
            }
        }

        quietly summarize S_end, meanonly
        scalar S_end_month = r(mean)
        gen double sigma = sqrt(ln(1 + sd^2))
        gen double mu    = ln(A_pc) - 0.5 * sigma^2
        gen double A_pc_ind = exp(rnormal(mu, sigma))
        gen double below_2100 = (A_pc_ind < R_fixed)
        gen double above_2100 = (A_pc_ind > R_fixed)
        quietly summarize A_pc_ind, meanonly
        scalar avg_pc = r(mean)
        quietly summarize below_2100, meanonly
        scalar share_below = r(mean)
        quietly summarize above_2100, meanonly
        scalar share_above = r(mean)
        post `Hnd_bs' (avg_pc) (S_end_month) (share_below) (share_above)
    }
    postclose `Hnd_bs'

    ******************************************************************
    * Carryover for next month 
    ******************************************************************
    use "bs_COGAT_`m'_`y'_CARRYOVER_noloss_excel.dta", clear
    quietly summarize mean_S_bs, meanonly
    scalar S0 = r(mean)
    di as result "→ Carryover stock to next month: " %10.0fc S0

    ci mean mean_pc_bs
    centile mean_pc_bs, centile(2.5 50 97.5)
}

******************************************************************
*  All monthly results
******************************************************************
local months "oct nov dec jan feb mar apr may jun jul aug sep oct nov dec"
local years  "2023 2023 2023 2024 2024 2024 2024 2024 2024 2024 2024 2024 2024 2024 2024"

tempfile results
save `results', emptyok replace

forvalues i = 1/15 {
    local m : word `i' of `months'
    local y : word `i' of `years'

    di "Summarizing month: `m' `y'"
    use "bs_COGAT_`m'_`y'_CARRYOVER_noloss_excel.dta", clear

    quietly centile mean_pc_bs, centile(2.5 50 97.5)
    scalar p2_5 = r(c_1)
    scalar p50  = r(c_2)
    scalar p97_5 = r(c_3)
    ci mean mean_pc_bs
    scalar mean = r(mean)
    scalar ll   = r(lb)
    scalar ul   = r(ub)
    ci mean share_below_2100
    scalar mean_share_below_2100 = r(mean)
    ci mean share_above_2100
    scalar mean_share_above_2100 = r(mean)
    quietly summarize mean_S_bs, meanonly
    scalar mean_S_bs_mean = r(mean)

    clear
    set obs 1
    gen year  = `y'
    gen month = `i' + 9 if `y'==2023
    replace month = `i' - 3 if `y'==2024

    gen mean_pc_bs_p2_5  = p2_5
    gen mean_pc_bs_p50   = p50
    gen mean_pc_bs_p97_5 = p97_5
    gen mean_pc_bs_mean  = mean
    gen ci_lower         = ll
    gen ci_upper         = ul
    gen mean_share_below_2100 = mean_share_below_2100
    gen mean_share_above_2100 = mean_share_above_2100
    gen mean_S_bs_mean = mean_S_bs_mean

    append using `results'
    save `results', replace
}
drop mean_pc_bs mean_S_bs share_below_2100 share_above_2100
drop if month == .
sort year month
save "bs_COGAT_summary_2023_2024_CARRYOVER_noloss_excel.dta", replace
* For the calculation of 5% loss and 15% loss, follow the logic of CALORIES AVAILABLE BOOTSTRAP