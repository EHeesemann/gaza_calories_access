*******************************************************
*  Gaza Food Availability Simulation – Free-consumption regime
*  With inter-month stockpile carryover
*  Period: Oct 2023 – Dec 2024
*******************************************************
clear all
set more off
set seed 12345

* ==== SCENARIO PARAMETERS ====
scalar lambda_in  = 0.00          // inflow leakage (adjust for scenario: 0.00, 0.05, 0.15)
scalar rho_S      = 0.000         // daily spoilage of stock
scalar capS       = .             // unlimited storage
scalar sd         = 0.20          // allowing for SD for CI calculation
scalar R_fixed    = 2100          // baseline kcal requirement
scalar B_bs       = 1000          // bootstrap replications

* ==== MONTHS AND YEARS ====
local months "oct nov dec jan feb mar apr may jun jul aug sep oct nov dec"
local years  "2023 2023 2023 2024 2024 2024 2024 2024 2024 2024 2024 2024 2024 2024 2024"

* ==== INITIAL STOCKPILE ====
* we can put it at zero since we have already incorporated the pre-stock in the calories calculation
scalar S0 = 0 

******************************************************************
*  MAIN MONTHLY LOOP – stockpile carried forward
******************************************************************
forvalues i = 1/15 {
    local m : word `i' of `months'
    local y : word `i' of `years'

    ******************************************************************
    * Reload main dataset each iteration
    ******************************************************************
	u "UN_PLATFORM_CALORIES_21_OCT_2023_31_DECEMBER_2024.dta", clear

keep date_var day month year calories_imp_20MT days_in_month population calories_internal_production 
order date_var day month year days_in_month population

preserve
import excel "stock_pre_war.xlsx", sheet("stock pre war") firstrow clear
format %15.0g tot_cal_pre_stock
tempfile pre
sa `pre'
restore

merge 1:1 date_var using  `pre'
drop _m
keep date_var day month year calories_imp_20MT days_in_month population calories_internal_production tot_cal_pre_stock
order date_var day month year days_in_month population

g tot_c_bis = calories_imp_20MT /*multiply here by the respective by 0.95 or 0.85 when running different loss asumption*/

egen b = rowtotal(calories_internal_production tot_cal_pre_stock tot_c_bis)

gen double kcal_pc = b/ population 
rename b K
gen ym    = ym(year, month)
format ym %tmMonYY
label var ym "Monthly date"


    * ==== POPULATION SERIES ====
    gen double N_t = .
    replace N_t = 2289696.195         if inrange(date_var, td(21oct2023), td(31oct2023))
    replace N_t = 2273871.69216661    if inrange(date_var, td(01nov2023), td(30nov2023))
    replace N_t = 2258156.55532267    if inrange(date_var, td(01dec2023), td(31dec2023))
    replace N_t = 2242550.02862014    if inrange(date_var, td(01jan2024), td(31jan2024))
    replace N_t = 2227051.36143476    if inrange(date_var, td(01feb2024), td(29feb2024))
    replace N_t = 2211659.80832999    if inrange(date_var, td(01mar2024), td(31mar2024))
    replace N_t = 2196374.62902111    if inrange(date_var, td(01apr2024), td(30apr2024))
    replace N_t = 2181195.08833967    if inrange(date_var, td(01may2024), td(31may2024))
    replace N_t = 2166120.45619809    if inrange(date_var, td(01jun2024), td(30jun2024))
    replace N_t = 2151150.00755454    if inrange(date_var, td(01jul2024), td(31jul2024))
    replace N_t = 2136283.0223781     if inrange(date_var, td(01aug2024), td(31aug2024))
    replace N_t = 2121518.78561413    if inrange(date_var, td(01sep2024), td(30sep2024))
    replace N_t = 2106856.58714982    if inrange(date_var, td(01oct2024), td(31oct2024))
    replace N_t = 2092295.72178012    if inrange(date_var, td(01nov2024), td(30nov2024))
    replace N_t = 2077835.48917376    if inrange(date_var, td(01dec2024), td(31dec2024))
    assert !missing(N_t)

    ******************************************************************
    * Taking into account months with different lenght
    ******************************************************************
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
        "bs_20MT_`m'_`y'_CARRYOVER_noloss.dta", replace

    forvalues b = 1/`=scalar(B_bs)' {
        use `monthdata', clear
        sort date_var

        * --- Apply inflow noise ---
        summarize K, meanonly
        scalar K_mean = r(mean)
        gen double relK = K / K_mean
        gen double inflow_sd = cond(relK < 0.5, 0.15, cond(relK < 1, 0.10, 0.05))
        gen double K_adj = K * (1 - lambda_in) * (1 + rnormal(-0.05, inflow_sd))
		
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

        * --- Daily loop ---
        gen double A_i   = .
        gen double S_end = .
        gen double A_pc  = .
        local S_prev = S0   // start from previous month's carryover, here we put 0 becasue in october we already incorporated pre-stock into the calories calculation, for loop after october it takes the s_prev month by month

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

        * --- Inequality layer ---
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
    * Update carryover for next month
    ******************************************************************
    use "bs_20MT_`m'_`y'_CARRYOVER_noloss.dta", clear
    quietly summarize mean_S_bs, meanonly
    scalar S0 = r(mean)
    di as result "→ Carryover stock to next month: " %10.0fc S0

    ci mean mean_pc_bs
    centile mean_pc_bs, centile(2.5 50 97.5)
    di as text "Month `m' `y' completed — results saved with carryover."
}

******************************************************************
*  POST-LOOP SUMMARY – combine all monthly results
******************************************************************
local months "oct nov dec jan feb mar apr may jun jul aug sep oct nov dec"
local years  "2023 2023 2023 2024 2024 2024 2024 2024 2024 2024 2024 2024 2024 2024 2024"

tempfile results
save `results', emptyok replace

forvalues i = 1/15 {
    local m : word `i' of `months'
    local y : word `i' of `years'

    di "Summarizing month: `m' `y'"
    use "bs_20MT_`m'_`y'_CARRYOVER_noloss.dta", clear

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

drop if month == .
sort year month
save "bs_20MT_summary_2023_2024_CARRYOVER_noloss.dta", replace
* For the calculation of 5% loss and 15% loss, follow the logic of CALORIES AVAILABLE BOOTSTRAP