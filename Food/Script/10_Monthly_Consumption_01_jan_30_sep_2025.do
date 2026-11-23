clear all
set more off
set seed 12345

/***********************************************************************
* NOTE ON SCENARIO SPECIFICATION AND REPRODUCIBILITY
*
* This do-file provides an example of the monthly caloric consumption
* estimation procedure for January–September 2025.
*
* The example implements:
*   - UN Platform pallets-based December 2024 stockpile scenario
*   - 15% loss applied to imported calories
*   - Moving-block bootstrap (7-day blocks, 1,000 replications)
*
* The same procedure can be adapted to alternative scenarios:
*
*   1. No loss (0%)
*   2. 5% loss
*   3. 15% loss (current example)
*
* The analysis can also be repeated using the December 2024
* stockpile estimates derived from:
*
*   - UN Platform pallets
*   - UN Platform 20 MT
*   - COGAT
*
* To reproduce an alternative scenario, users should modify:
*
*   a) The loss factor applied to imported calories (tot_c_bis).
*   b) The initial stockpile at 31 December 2024 (S_prev).
*   c) The input caloric series, where applicable.
*   d) The output filenames to identify the selected scenario.
*
* The remaining model structure, stockpile accounting equations,
* and bootstrap procedure can be applied consistently.
*
* IMPORTANT:
* Loss assumptions and initial stockpile values must be consistent
* with the selected data source and scenario. Where carryover stock
* is recalculated from previous months, the same assumptions must
* be maintained throughout the historical reconstruction.
***********************************************************************/

********************************************************************************
* BLOCK BOOTSTRAP — 
* - Non-parametric resampling of contiguous blocks (length L)
* - Tracks stockpile (S_open/S_end), daily ration, and summarizes mean ration
********************************************************************************

import excel "COGAT_DATA_OCT_2023_SEPTEMBER_2025.xlsx", sheet("COGAT DATA") firstrow clear
keep if date_var > td(31dec2024)
ren INTERNALPRODUCTIONTOTALCALORI calories_internal_production
ren PREWARSTOCKTOTALCALORIES tot_cal_pre_stock
ren IMPORTATIONTOTALCALORIES tot_c
ren POPULATION population
format %15.0g tot_c

generate day = day(date_var)
generate month = month(date_var)
generate year = year(date_var)
gen ym    = ym(year, month)
format ym %tmMonYY
label var ym "Monthly date"

keep date_var day month year population tot_c calories_internal_production

g tot_c_bis = (tot_c*0.85) 
format %15.0g tot_c_bis
egen b = rowtotal(calories_internal_production tot_c_bis)
format %15.0g b

ren b K
set seed 12345

ren date_var DAY
keep if DAY <= td(31jan2025) 

* ---------- PARAMETERS ----------
scalar N          = 2063015.86507594     // population
scalar lambda_in  = 0.00         // inflow leakage (0..1) - Already incorporated in the calculation of tot_c_bis, so we put it at zero
scalar rho_S      = 0.0025         // daily stock spoilage (0..1)
scalar capS       = .            // storage capacity ('.' = none)
scalar phi_thru   = 1.00         // delivery efficiency * we don't know that, so we put full efficiency
scalar L          = 7            // block length for bootstrap
scalar B_bs       = 1000         // bootstrap replicates

* ---------- TARGET SERIES ----------
set seed 12345
capture drop R_target
gen double R_target = .

replace R_target = 1950 if inrange(DAY, td(01jan2025), td(15jan2025))
replace R_target = 2100 if inrange(DAY, td(16jan2025), td(31jan2025))
assert !missing(R_target)

* ---------- SAVE ORIGINAL ORDERED DATA ----------
sort DAY
tempfile original
preserve
keep DAY K R_target
gen int orig = _n
save `original', replace
restore

* ---------- SETUP OUTPUT ----------
tempname Hnd_bs
postfile `Hnd_bs' mean_pc_bs mean_S_bs using ///
    "bs_JANUARY_2025_15_PC_LOSS_EXCEL_PALLETS.dta", replace

* ---------- BOOTSTRAP LOOP ----------
use `original', clear
count
scalar T = r(N)

forvalues b = 1/`=scalar(B_bs)' {
    * Step 1: Build bootstrap index
    clear
    set obs `=scalar(T)'
    gen int pos = .
    local filled = 0
    while `filled' < T {
        local start = ceil(runiform() * (T - L + 1))
        forvalues j = 0/`=L-1' {
            local idx = `filled' + `j' + 1
            if `idx' <= T replace pos = `start' + `j' in `idx'
        }
        local filled = `filled' + L
    }

    rename pos orig
    merge m:1 orig using `original', nogen keep(match)

    drop DAY
    gen double DAY = _n

    gen double K_adj = K 
    capture drop S_open S_end cons_pc mean_pc surplus_used
    gen double S_open       = .
    gen double S_end        = .
    gen double cons_pc      = .
    gen double mean_pc      = .
    gen double surplus_used = .
	
	* ==========================================================================
    * >>> INITIAL STOCKPILE FOR JANUARY CHECK THE NO LOSS STOCK<<<
    * January begins with (see below) kcal/person × January population (from 31 December 2024) to be chosen according to the platform and truck's weight
    * ==========================================================================
    *local S_prev =      24415 * N /*COGAT*/
	*local S_prev =       1976 * N /*MT20*/
	local S_prev =          0 * N /*PALLETS*/

    quietly {
        forvalues i = 1/`=_N' {
            scalar S_eff  = `S_prev' * (1 - rho_S)
            scalar P_i    = K_adj[`i'] + S_eff
            scalar R_need = R_target * N

            * Actual allocation:
            * If enough, cap at R_need and put remainder in stock
            * If not enough, consume all (per capita < R_target)
            scalar A_i = min(P_i, R_need)

            * Surplus stock update
            scalar S_new = P_i - A_i
            if (capS<.) scalar S_new = min(S_new, capS)
            if (S_new<0) scalar S_new = 0

            scalar pc = A_i / N

            replace S_open       = S_eff   in `i'
            replace S_end        = S_new   in `i'
            replace cons_pc      = pc      in `i'
            replace mean_pc      = pc      in `i'
            replace surplus_used = S_new   in `i'

            local S_prev = S_new
        }
    }

    quietly summarize mean_pc, meanonly
    scalar avg_pc = r(mean)
    quietly summarize S_end, meanonly
    scalar avg_S  = r(mean)

    post `Hnd_bs' (avg_pc) (avg_S)
}
postclose `Hnd_bs'

* ---------- SUMMARIZE ----------
use "bs_JANUARY_2025_15_PC_LOSS_EXCEL_PALLETS.dta", clear
display as text "Block bootstrap: median and 95% CI of period mean kcal/person"
centile mean_pc_bs, centile(2.5 50 97.5)

********************************************************************************
* FEBRUARY 2025
********************************************************************************

import excel "COGAT_DATA_OCT_2023_SEPTEMBER_2025.xlsx", sheet("COGAT DATA") firstrow clear
keep if date_var > td(31dec2024)
ren INTERNALPRODUCTIONTOTALCALORI calories_internal_production
ren PREWARSTOCKTOTALCALORIES tot_cal_pre_stock
ren IMPORTATIONTOTALCALORIES tot_c
ren POPULATION population
format %15.0g tot_c

generate day = day(date_var)
generate month = month(date_var)
generate year = year(date_var)
gen ym    = ym(year, month)
format ym %tmMonYY
label var ym "Monthly date"

keep date_var day month year population tot_c calories_internal_production

g tot_c_bis = (tot_c*0.85) 
format %15.0g tot_c_bis
egen b = rowtotal(calories_internal_production tot_c_bis)
format %15.0g b

ren b K
set seed 12345
ren date_var DAY

keep if inrange(DAY, td(01feb2025), td(28feb2025))

* ---------- PARAMETERS ----------
scalar N          =  2048301.93811322     // population
scalar lambda_in  = 0.00         // inflow leakage (0..1)
scalar rho_S      = 0.0045         // daily stock spoilage (0..1)
scalar capS       = .            // storage capacity ('.' = none)
scalar phi_thru   = 1.00         // delivery efficiency
scalar L          = 7            // block length for bootstrap
scalar B_bs       = 1000         // bootstrap replicates


* ---------- TARGET SERIES (recreate to be safe) ----------
capture drop R_target
gen double R_target = .
replace R_target = 2200 if inrange(DAY, td(01feb2025), td(28feb2025)) /*put at 2200 to better calculate CI*/
assert !missing(R_target)

* ---------- SAVE ORIGINAL ORDERED DATA ----------
sort DAY
tempfile original
preserve
keep DAY K R_target
gen int orig = _n
save `original', replace
restore

* ---------- SETUP OUTPUT ----------
tempname Hnd_bs
postfile `Hnd_bs' mean_pc_bs mean_S_bs using ///
    "bs_FEBRUARY_2025_15_PC_LOSS_EXCEL_PALLETS.dta", replace

* ---------- BOOTSTRAP LOOP ----------
use `original', clear
count
scalar T = r(N)

forvalues b = 1/`=scalar(B_bs)' {
    * Step 1: Build bootstrap index
    clear
    set obs `=scalar(T)'
    gen int pos = .
    local filled = 0
    while `filled' < T {
        local start = ceil(runiform() * (T - L + 1))
        forvalues j = 0/`=L-1' {
            local idx = `filled' + `j' + 1
            if `idx' <= T replace pos = `start' + `j' in `idx'
        }
        local filled = `filled' + L
    }

    * Step 2: Map resampled indices
    rename pos orig
    merge m:1 orig using `original', nogen keep(match)

    drop DAY
    gen double DAY = _n

    * Adjust inflow after leakage
    gen double K_adj = K * (1 - lambda_in)

    * Tracking
    capture drop S_open S_end cons_pc mean_pc surplus_used
    gen double S_open       = .
    gen double S_end        = .
    gen double cons_pc      = .
    gen double mean_pc      = .
    gen double surplus_used = .

    local S_prev = 90481
    quietly {
        forvalues i = 1/`=_N' {
            scalar S_eff  = `S_prev' * (1 - rho_S)
            scalar P_i    = K_adj[`i'] + S_eff
            scalar R_need = R_target * N

            * Actual allocation:
            * If enough, cap at R_need and put remainder in stock
            * If not enough, consume all (per capita < R_target)
            scalar A_i = min(P_i, R_need)

            * Surplus stock update
            scalar S_new = P_i - A_i
            if (capS<.) scalar S_new = min(S_new, capS)
            if (S_new<0) scalar S_new = 0

            scalar pc = A_i / N

            replace S_open       = S_eff   in `i'
            replace S_end        = S_new   in `i'
            replace cons_pc      = pc      in `i'
            replace mean_pc      = pc      in `i'
            replace surplus_used = S_new   in `i'

            local S_prev = S_new
        }
    }

    quietly summarize mean_pc, meanonly
    scalar avg_pc = r(mean)
    quietly summarize S_end, meanonly
    scalar avg_S  = r(mean)

    post `Hnd_bs' (avg_pc) (avg_S)
}

postclose `Hnd_bs'

* ---------- SUMMARIZE ----------
use "bs_FEBRUARY_2025_15_PC_LOSS_EXCEL_PALLETS.dta", clear
display as text "Block bootstrap: median and 95% CI of period mean kcal/person"
centile mean_pc_bs, centile(2.5 50 97.5)

********************************************************************************
* Now we rerun January and February only to consider the stockpile
********************************************************************************
******************************************************************
* Carryover stock into March from Jan–Feb, POPULATION varies by month
******************************************************************/
import excel "COGAT_DATA_OCT_2023_SEPTEMBER_2025.xlsx", sheet("COGAT DATA") firstrow clear
keep if date_var > td(31dec2024)
ren INTERNALPRODUCTIONTOTALCALORI calories_internal_production
ren PREWARSTOCKTOTALCALORIES tot_cal_pre_stock
ren IMPORTATIONTOTALCALORIES tot_c
ren POPULATION population
format %15.0g tot_c

generate day = day(date_var)
generate month = month(date_var)
generate year = year(date_var)
gen ym    = ym(year, month)
format ym %tmMonYY
label var ym "Monthly date"

keep date_var day month year population tot_c calories_internal_production

g tot_c_bis = (tot_c*0.85) 
format %15.0g tot_c_bis
egen b = rowtotal(calories_internal_production tot_c_bis)
format %15.0g b

ren b K
set seed 12345
ren date_var DAY

set seed 12345

keep if inrange(DAY, td(01jan2025), td(31mar2025))

* ---------- CONSTANT PARAMETERS ----------
scalar lambda_in  = 0.000         // inflow leakage
scalar rho_S      = 0.0065         // daily spoilage of stock
scalar capS       = .            // storage capacity ('.' means unlimited)

* Distribution layer
scalar dist_mode  = 1            // 1=lognormal (cv), 2=two-group
scalar cv_pc      = 0.25         // only if dist_mode==1
scalar alpha_hi   = 0.20         // only if dist_mode==2
scalar delta_hi   = 0.20         // only if dist_mode==2

* Bootstrap
scalar L          = 7
scalar B_bs       = 1000

* ---------- DAILY TARGET SERIES ----------
capture drop R_target
gen double R_target = .
replace R_target = 2000 if inrange(DAY, td(01jan2025), td(19jan2025))
replace R_target = 2200 if inrange(DAY, td(20jan2025), td(31jan2025))
replace R_target = 2200 if inrange(DAY, td(01feb2025), td(28feb2025))
replace R_target = 2100 if inrange(DAY, td(01mar2025), td(14mar2025))
replace R_target = 1995 if inrange(DAY, td(15mar2025), td(28mar2025))
replace R_target = 1890 if inrange(DAY, td(29mar2025), td(31mar2025))
assert !missing(R_target)

* ---------- DAILY POPULATION SERIES ----------
capture drop N_t
gen double N_t = .
replace N_t = 2019188.16553987 if inrange(DAY, td(01jan2025), td(31jan2025))  // January
replace N_t = 2004786.82830602 if inrange(DAY, td(01feb2025), td(28feb2025))  // February
replace N_t = 1990488.20488441 if inrange(DAY, td(01mar2025), td(31mar2025))  // March
assert !missing(N_t)

******************************************************************
* PART A: Compute end-of-February stock S0 using ACTUAL Jan–Feb
******************************************************************
preserve
    keep if inrange(DAY, td(01jan2025), td(28feb2025))
    sort DAY

    gen double K_adj = K * (1 - lambda_in)
    tempvar S_open S_end pc
    gen double `S_open' = .
    gen double `S_end'  = .
    gen double `pc'     = .

    local S_prev = 0
    quietly {
        forvalues i = 1/`=_N' {
            scalar S_eff  = `S_prev' * (1 - rho_S)
            scalar P_i    = K_adj[`i'] + S_eff

            * USE daily population and daily target
            scalar R_need = R_target[`i'] * N_t[`i']
            scalar A_i    = min(P_i, R_need)

            scalar S_new  = P_i - A_i
            if (capS<.) scalar S_new = min(S_new, capS)
            if (S_new<0) scalar S_new = 0

            replace `S_open' = S_eff in `i'
            replace `S_end'  = S_new in `i'
            replace `pc'     = A_i / N_t[`i'] in `i'

            local S_prev = S_new
        }
    }

    * Carryover stock for March: take LAST day's stock, not the max
    sort DAY
    scalar S0 = `S_end'[_N]
restore

di as txt "Initial carryover stock for March (S0): " as res %15.0gc S0

******************************************************************
* PART B: Bootstrap March ONLY, with initial stock = S0 each rep
******************************************************************
preserve
    keep if inrange(DAY, td(01mar2025), td(31mar2025))
    sort DAY

    * Build daily target that will travel with each row through resampling
    gen double R_tgt = .
    replace R_tgt = 2100 if inrange(DAY, td(01mar2025), td(14mar2025))
    replace R_tgt = 1995 if inrange(DAY, td(15mar2025), td(28mar2025))
    replace R_tgt = 1890 if inrange(DAY, td(29mar2025), td(31mar2025))

    keep DAY K R_tgt N_t
    gen int orig = _n
    tempfile march
    save `march', replace
restore

* Output file: under daily target and under fixed 2100
tempname Hnd_bs
postfile `Hnd_bs' mean_pc_bs mean_S_bs mean_under_target_bs mean_under_2100_bs using ///
    "bs_MARCH_2025_15_PC_LOSS_EXCEL_PALLETS.dta", replace

use `march', clear
count
scalar T = r(N)

* For the fixed-threshold comparison
scalar R_fixed = 2100

forvalues b = 1/`=scalar(B_bs)' {
    * Moving-block bootstrap indices over March
    clear
    set obs `=scalar(T)'
    gen int pos = .
    local filled = 0
    while `filled' < T {
        local start = ceil(runiform() * (T - L + 1))
        forvalues j = 0/`=L-1' {
            local idx = `filled' + `j' + 1
            if `idx' <= T replace pos = `start' + `j' in `idx'
        }
        local filled = `filled' + L
    }

    * Map to March series (K, R_tgt, N_t travel with the row)
    rename pos orig
    merge m:1 orig using `march', nogen keep(match)

    drop DAY
    gen double DAY = _n

    gen double K_adj = K * (1 - lambda_in)

    capture drop S_open S_end pc p_under_target p_under_2100 ///
                 share_under_target share_under_2100
    gen double S_open             = .
    gen double S_end              = .
    gen double pc                 = .
    gen double p_under_target     = .
    gen double p_under_2100       = .
    gen double share_under_target = .
    gen double share_under_2100   = .

    * >>> Seed March with carryover S0 from Jan–Feb deterministic pass <<<
    local S_prev = S0

    quietly {
        forvalues i = 1/`=_N' {
            scalar S_eff   = `S_prev' * (1 - rho_S)
            scalar P_i     = K_adj[`i'] + S_eff

            * DAILY cap uses DAILY POP
            scalar R_need  = R_tgt[`i'] * N_t[`i']
            scalar A_i     = min(P_i, R_need)

            scalar S_new   = P_i - A_i
            if (capS<.) scalar S_new = min(S_new, capS)
            if (S_new<0)  scalar S_new = 0

            scalar pc_i    = A_i / N_t[`i']

            replace S_open = S_eff in `i'
            replace S_end  = S_new in `i'
            replace pc     = pc_i  in `i'

            * ----- Distributional layer: two thresholds -----
            if (dist_mode==1) {
                if (pc_i<=0) {
                    scalar p_tgt = 1
                    scalar p_210 = 1
                }
                else {
                    scalar sigma = sqrt(ln(1 + cv_pc^2))
                    scalar mu    = ln(pc_i) - 0.5*sigma^2
                    scalar z_tgt = (ln(R_tgt[`i']) - mu) / sigma
                    scalar z_210 = (ln(R_fixed)   - mu) / sigma
                    scalar p_tgt = normal(z_tgt)
                    scalar p_210 = normal(z_210)
                }
                replace p_under_target     = p_tgt in `i'
                replace p_under_2100       = p_210 in `i'
                replace share_under_target = p_tgt in `i'
                replace share_under_2100   = p_210 in `i'
            }
            else if (dist_mode==2) {
                * Two-group split with DAILY hi-cap tied to R_tgt and DAILY POP
                scalar hi_cap    = (1 + delta_hi) * R_tgt[`i']
                scalar A_tot     = pc_i * N_t[`i']
                scalar A_hi_need = alpha_hi * N_t[`i'] * hi_cap

                scalar hi_pc = .
                scalar lo_pc = .

                if (A_tot >= A_hi_need) {
                    scalar hi_pc = hi_cap
                    scalar A_lo  = A_tot - A_hi_need
                    scalar lo_pc = A_lo / ((1 - alpha_hi) * N_t[`i'])
                }
                else {
                    * Not enough to hit hi-cap → proportional shortfall
                    scalar hi_pc = A_tot / (alpha_hi * N_t[`i'])
                    scalar lo_pc = 0
                }

                scalar share_tgt = 0
                if (hi_pc < R_tgt[`i']) scalar share_tgt = share_tgt + alpha_hi
                if (lo_pc < R_tgt[`i']) scalar share_tgt = share_tgt + (1 - alpha_hi)

                scalar share_210 = 0
                if (hi_pc < R_fixed)     scalar share_210 = share_210 + alpha_hi
                if (lo_pc < R_fixed)     scalar share_210 = share_210 + (1 - alpha_hi)

                replace p_under_target     = share_tgt in `i'
                replace p_under_2100       = share_210 in `i'
                replace share_under_target = share_tgt in `i'
                replace share_under_2100   = share_210 in `i'
            }

            local S_prev = S_new
        }
    }

    quietly summarize pc, meanonly
    scalar avg_pc = r(mean)
    quietly summarize S_end, meanonly
    scalar avg_S  = r(mean)
    quietly summarize share_under_target, meanonly
    scalar avg_under_tgt = r(mean)
    quietly summarize share_under_2100, meanonly
    scalar avg_under_210 = r(mean)

    post `Hnd_bs' (avg_pc) (avg_S) (avg_under_tgt) (avg_under_210)
}

postclose `Hnd_bs'

/*** Outputs:
- bs_MARCH_2025_with_carryover.dta with variables:
    mean_pc_bs          = average March per-capita intake (kcal)
    mean_S_bs           = average March end-of-day stock (kcal)
    mean_share_under_bs = average daily share < 2,100 kcal
- The initial carryover stock S0 is computed from actual Jan–Feb.
***/
use "bs_MARCH_2025_15_PC_LOSS_EXCEL_PALLETS.dta", clear
display as text "Block bootstrap: median and 95% CI of period mean kcal/person"
centile mean_pc_bs, centile(2.5 50 97.5)

******************************************************************
* Carryover stock into April from Jan–Mar, POPULATION varies by month
******************************************************************/
import excel "COGAT_DATA_OCT_2023_SEPTEMBER_2025.xlsx", sheet("COGAT DATA") firstrow clear
keep if date_var > td(31dec2024)
ren INTERNALPRODUCTIONTOTALCALORI calories_internal_production
ren PREWARSTOCKTOTALCALORIES tot_cal_pre_stock
ren IMPORTATIONTOTALCALORIES tot_c
ren POPULATION population
format %15.0g tot_c

generate day = day(date_var)
generate month = month(date_var)
generate year = year(date_var)
gen ym    = ym(year, month)
format ym %tmMonYY
label var ym "Monthly date"

keep date_var day month year population tot_c calories_internal_production

g tot_c_bis = (tot_c*0.85) 
format %15.0g tot_c_bis
egen b = rowtotal(calories_internal_production tot_c_bis)
format %15.0g b

ren b K
set seed 12345

ren date_var DAY
keep if inrange(DAY, td(01jan2025), td(30apr2025))

* ---------- CONSTANT PARAMETERS ----------
scalar lambda_in  = 0.000         // inflow leakage
scalar rho_S      = 0.0075         // daily spoilage of stock
scalar capS       = .            // storage capacity ('.' means unlimited)

* Distribution layer
scalar dist_mode  = 1            // 1=lognormal (cv), 2=two-group
scalar cv_pc      = 0.25         // only if dist_mode==1
scalar alpha_hi   = 0.20         // only if dist_mode==2
scalar delta_hi   = 0.20         // only if dist_mode==2

* Bootstrap
scalar L          = 7
scalar B_bs       = 1000

* ---------- DAILY TARGET SERIES (EDIT APRIL IF NEEDED) ----------
capture drop R_target
gen double R_target = .
replace R_target = 2000 if inrange(DAY, td(01jan2025), td(19jan2025))
replace R_target = 2100 if inrange(DAY, td(20jan2025), td(31jan2025))
replace R_target = 2200 if inrange(DAY, td(01feb2025), td(28feb2025))
replace R_target = 2100 if inrange(DAY, td(01mar2025), td(14mar2025))
replace R_target = 1995 if inrange(DAY, td(15mar2025), td(28mar2025))
replace R_target = 1890 if inrange(DAY, td(29mar2025), td(31mar2025))
replace R_target = 1890 if inrange(DAY, td(01apr2025), td(11apr2025))
replace R_target = 1785 if inrange(DAY, td(12apr2025), td(25apr2025))
replace R_target = 1680 if inrange(DAY, td(26apr2025), td(30apr2025))
assert !missing(R_target)

* ---------- DAILY POPULATION SERIES ----------
capture drop N_t
gen double N_t = .
replace N_t = 2063015.86507594 if inrange(DAY, td(01jan2025), td(31jan2025))  // January
replace N_t = 2048301.93811322 if inrange(DAY, td(01feb2025), td(28feb2025))  // February
replace N_t = 2033692.95442813 if inrange(DAY, td(01mar2025), td(31mar2025))  // March
replace N_t = 2019188.16553987 if inrange(DAY, td(01apr2025), td(30apr2025))  // April
assert !missing(N_t)

******************************************************************
* PART A: Compute end-of-March stock S0 using ACTUAL Jan–Mar
******************************************************************
preserve
    keep if inrange(DAY, td(01jan2025), td(31mar2025))
    sort DAY

    gen double K_adj = K * (1 - lambda_in)
    tempvar S_open S_end pc
    gen double `S_open' = .
    gen double `S_end'  = .
    gen double `pc'     = .

    local S_prev = 0
    quietly {
        forvalues i = 1/`=_N' {
            scalar S_eff  = `S_prev' * (1 - rho_S)
            scalar P_i    = K_adj[`i'] + S_eff

            * USE daily population and daily target
            scalar R_need = R_target[`i'] * N_t[`i']
            scalar A_i    = min(P_i, R_need)

            scalar S_new  = P_i - A_i
            if (capS<.) scalar S_new = min(S_new, capS)
            if (S_new<0) scalar S_new = 0

            replace `S_open' = S_eff in `i'
            replace `S_end'  = S_new in `i'
            replace `pc'     = A_i / N_t[`i'] in `i'

            local S_prev = S_new
        }
    }

    * Carryover stock for April: LAST day's stock (since sorted)
    sort DAY
    scalar S0 = `S_end'[_N]
restore

di as txt "Initial carryover stock for April (S0): " as res %15.0gc S0

******************************************************************
* PART B: Bootstrap April ONLY, with initial stock = S0 each rep
******************************************************************
preserve
    keep if inrange(DAY, td(01apr2025), td(30apr2025))
    sort DAY

    * Build daily target & pop that travel with each resampled row
    gen double R_tgt = R_target
    keep DAY K R_tgt N_t
    gen int orig = _n
    tempfile april
    save `april', replace
restore

* Output file: under daily target and under fixed 2100
tempname Hnd_bs
postfile `Hnd_bs' mean_pc_bs mean_S_bs mean_under_target_bs mean_under_2100_bs using ///
    "bs_APRIL_2025_15_PC_LOSS_EXCEL_PALLETS.dta", replace

use `april', clear
count
scalar T = r(N)

* For the fixed-threshold comparison
scalar R_fixed = 2100

forvalues b = 1/`=scalar(B_bs)' {
    * Moving-block bootstrap indices over April
    clear
    set obs `=scalar(T)'
    gen int pos = .
    local filled = 0
    while `filled' < T {
        local start = ceil(runiform() * (T - L + 1))
        forvalues j = 0/`=L-1' {
            local idx = `filled' + `j' + 1
            if `idx' <= T replace pos = `start' + `j' in `idx'
        }
        local filled = `filled' + L
    }

    * Map to April series (K, R_tgt, N_t travel with the row)
    rename pos orig
    merge m:1 orig using `april', nogen keep(match)

    drop DAY
    gen double DAY = _n

    gen double K_adj = K * (1 - lambda_in)

    capture drop S_open S_end pc p_under_target p_under_2100 ///
                 share_under_target share_under_2100
    gen double S_open             = .
    gen double S_end              = .
    gen double pc                 = .
    gen double p_under_target     = .
    gen double p_under_2100       = .
    gen double share_under_target = .
    gen double share_under_2100   = .

    * >>> Seed April with carryover S0 from Jan–Mar deterministic pass <<<
    local S_prev = S0

    quietly {
        forvalues i = 1/`=_N' {
            scalar S_eff   = `S_prev' * (1 - rho_S)
            scalar P_i     = K_adj[`i'] + S_eff

            * DAILY cap uses DAILY POP
            scalar R_need  = R_tgt[`i'] * N_t[`i']
            scalar A_i     = min(P_i, R_need)

            scalar S_new   = P_i - A_i
            if (capS<.) scalar S_new = min(S_new, capS)
            if (S_new<0)  scalar S_new = 0

            scalar pc_i    = A_i / N_t[`i']

            replace S_open = S_eff in `i'
            replace S_end  = S_new in `i'
            replace pc     = pc_i  in `i'

            * ----- Distributional layer: two thresholds -----
            if (dist_mode==1) {
                if (pc_i<=0) {
                    scalar p_tgt = 1
                    scalar p_210 = 1
                }
                else {
                    scalar sigma = sqrt(ln(1 + cv_pc^2))
                    scalar mu    = ln(pc_i) - 0.5*sigma^2
                    scalar z_tgt = (ln(R_tgt[`i']) - mu) / sigma
                    scalar z_210 = (ln(R_fixed)   - mu) / sigma
                    scalar p_tgt = normal(z_tgt)
                    scalar p_210 = normal(z_210)
                }
                replace p_under_target     = p_tgt in `i'
                replace p_under_2100       = p_210 in `i'
                replace share_under_target = p_tgt in `i'
                replace share_under_2100   = p_210 in `i'
            }
            else if (dist_mode==2) {
                * Two-group split with DAILY hi-cap tied to R_tgt and DAILY POP
                scalar hi_cap    = (1 + delta_hi) * R_tgt[`i']
                scalar A_tot     = pc_i * N_t[`i']
                scalar A_hi_need = alpha_hi * N_t[`i'] * hi_cap

                scalar hi_pc = .
                scalar lo_pc = .

                if (A_tot >= A_hi_need) {
                    scalar hi_pc = hi_cap
                    scalar A_lo  = A_tot - A_hi_need
                    scalar lo_pc = A_lo / ((1 - alpha_hi) * N_t[`i'])
                }
                else {
                    * Not enough to hit hi-cap → proportional shortfall
                    scalar hi_pc = A_tot / (alpha_hi * N_t[`i'])
                    scalar lo_pc = 0
                }

                scalar share_tgt = 0
                if (hi_pc < R_tgt[`i']) scalar share_tgt = share_tgt + alpha_hi
                if (lo_pc < R_tgt[`i']) scalar share_tgt = share_tgt + (1 - alpha_hi)

                scalar share_210 = 0
                if (hi_pc < R_fixed)     scalar share_210 = share_210 + alpha_hi
                if (lo_pc < R_fixed)     scalar share_210 = share_210 + (1 - alpha_hi)

                replace p_under_target     = share_tgt in `i'
                replace p_under_2100       = share_210 in `i'
                replace share_under_target = share_tgt in `i'
                replace share_under_2100   = share_210 in `i'
            }

            local S_prev = S_new
        }
    }

    quietly summarize pc, meanonly
    scalar avg_pc = r(mean)
    quietly summarize S_end, meanonly
    scalar avg_S  = r(mean)
    quietly summarize share_under_target, meanonly
    scalar avg_under_tgt = r(mean)
    quietly summarize share_under_2100, meanonly
    scalar avg_under_210 = r(mean)

    post `Hnd_bs' (avg_pc) (avg_S) (avg_under_tgt) (avg_under_210)
}

postclose `Hnd_bs'

use "bs_APRIL_2025_15_PC_LOSS_EXCEL_PALLETS.dta", clear
display as text "Block bootstrap: median and 95% CI of period mean kcal/person"
centile mean_pc_bs, centile(2.5 50 97.5)


******************************************************************
* Carryover stock into May (1–18) from Jan–Apr, POP varies by month
******************************************************************/
import excel "COGAT_DATA_OCT_2023_SEPTEMBER_2025.xlsx", sheet("COGAT DATA") firstrow clear
keep if date_var > td(31dec2024)
ren INTERNALPRODUCTIONTOTALCALORI calories_internal_production
ren PREWARSTOCKTOTALCALORIES tot_cal_pre_stock
ren IMPORTATIONTOTALCALORIES tot_c
ren POPULATION population
format %15.0g tot_c

generate day = day(date_var)
generate month = month(date_var)
generate year = year(date_var)
gen ym    = ym(year, month)
format ym %tmMonYY
label var ym "Monthly date"

keep date_var day month year population tot_c calories_internal_production

g tot_c_bis = (tot_c*0.85) 
format %15.0g tot_c_bis
egen b = rowtotal(calories_internal_production tot_c_bis)
format %15.0g b

ren b K
set seed 12345

ren date_var DAY
keep if inrange(DAY, td(01jan2025), td(18may2025))

* ---------- CONSTANT PARAMETERS ----------
scalar lambda_in  = 0.000         // inflow leakage
scalar rho_S      = 0.0105        // daily spoilage of stock
scalar capS       = .            // storage capacity ('.' means unlimited)

* Distribution layer
scalar dist_mode  = 1            // 1=lognormal (cv), 2=two-group
scalar cv_pc      = 0.25         // only if dist_mode==1
scalar alpha_hi   = 0.20         // only if dist_mode==2
scalar delta_hi   = 0.20         // only if dist_mode==2

* Bootstrap
scalar L          = 7
scalar B_bs       = 1000

* ---------- DAILY TARGET SERIES (EDIT if May differs) ----------
capture drop R_target
gen double R_target = .
replace R_target = 2000 if inrange(DAY, td(01jan2025), td(19jan2025))
replace R_target = 2300 if inrange(DAY, td(20jan2025), td(31jan2025))
replace R_target = 2300 if inrange(DAY, td(01feb2025), td(28feb2025))
replace R_target = 2100 if inrange(DAY, td(01mar2025), td(14mar2025))
replace R_target = 1995 if inrange(DAY, td(15mar2025), td(28mar2025))
replace R_target = 1890 if inrange(DAY, td(29mar2025), td(31mar2025))
replace R_target = 1890 if inrange(DAY, td(01apr2025), td(11apr2025))
replace R_target = 1785 if inrange(DAY, td(12apr2025), td(25apr2025))
replace R_target = 1680 if inrange(DAY, td(26apr2025), td(30apr2025))
replace R_target = 1680 if inrange(DAY, td(01may2025), td(09may2025))
replace R_target = 1407 if inrange(DAY, td(10may2025), td(18may2025))
assert !missing(R_target)

* ---------- DAILY POPULATION SERIES ----------
capture drop N_t
gen double N_t = .
replace N_t = 2063015.86507594 if inrange(DAY, td(01jan2025), td(31jan2025))  // January
replace N_t = 2048301.93811322 if inrange(DAY, td(01feb2025), td(28feb2025))  // February
replace N_t = 2033692.95442813 if inrange(DAY, td(01mar2025), td(31mar2025))  // March
replace N_t = 2019188.16553987 if inrange(DAY, td(01apr2025), td(30apr2025))  // April
replace N_t = 2004786.82830602 if inrange(DAY, td(01may2025), td(18may2025))  // May (1–18)
assert !missing(N_t)

******************************************************************
* PART A: Compute end-of-April stock S0 using ACTUAL Jan–Apr
******************************************************************
preserve
    keep if inrange(DAY, td(01jan2025), td(30apr2025))
    sort DAY

    gen double K_adj = K * (1 - lambda_in)
    tempvar S_end
    gen double `S_end' = .

    local S_prev = 0
    quietly {
        forvalues i = 1/`=_N' {
            scalar S_eff  = `S_prev' * (1 - rho_S)
            scalar P_i    = K_adj[`i'] + S_eff

            scalar R_need = R_target[`i'] * N_t[`i']   // daily target × daily pop
            scalar A_i    = min(P_i, R_need)

            scalar S_new  = P_i - A_i
            if (capS<.) scalar S_new = min(S_new, capS)
            if (S_new<0) scalar S_new = 0

            replace `S_end' = S_new in `i'
            local S_prev = S_new
        }
    }

    sort DAY
    scalar S0 = `S_end'[_N]     // carryover stock for May 1
restore

di as txt "Initial carryover stock for May (S0): " as res %15.0gc S0

******************************************************************
* PART B: Bootstrap May 1–18 ONLY, with initial stock = S0
******************************************************************
preserve
    keep if inrange(DAY, td(01may2025), td(18may2025))
    sort DAY

    gen double R_tgt = R_target   // daily targets
    keep DAY K R_tgt N_t
    gen int orig = _n
    tempfile may
    save `may', replace
restore

tempname Hnd_bs
postfile `Hnd_bs' mean_pc_bs mean_S_bs mean_under_target_bs mean_under_2100_bs using ///
    "bs_MAY_18_2025_15_PC_LOSS_EXCEL_PALLETS.dta", replace

use `may', clear
count
scalar T = r(N)

scalar R_fixed = 2100   // fixed humanitarian benchmark

forvalues b = 1/`=scalar(B_bs)' {
    * Moving-block bootstrap indices over May 1–18
    clear
    set obs `=scalar(T)'
    gen int pos = .
    local filled = 0
    while `filled' < T {
        local start = ceil(runiform() * (T - L + 1))
        forvalues j = 0/`=L-1' {
            local idx = `filled' + `j' + 1
            if `idx' <= T replace pos = `start' + `j' in `idx'
        }
        local filled = `filled' + L
    }

    * Map to May series (K, R_tgt, N_t travel with the row)
    rename pos orig
    merge m:1 orig using `may', nogen keep(match)

    drop DAY
    gen double DAY = _n

    gen double K_adj = K * (1 - lambda_in)

    capture drop S_open S_end pc p_under_target p_under_2100 ///
                 share_under_target share_under_2100
    gen double S_open             = .
    gen double S_end              = .
    gen double pc                 = .
    gen double p_under_target     = .
    gen double p_under_2100       = .
    gen double share_under_target = .
    gen double share_under_2100   = .

    * Seed with carryover S0 from Jan–Apr pass
    local S_prev = S0

    quietly {
        forvalues i = 1/`=_N' {
            scalar S_eff   = `S_prev' * (1 - rho_S)
            scalar P_i     = K_adj[`i'] + S_eff

            scalar R_need  = R_tgt[`i'] * N_t[`i']   // daily cap with daily pop
            scalar A_i     = min(P_i, R_need)

            scalar S_new   = P_i - A_i
            if (capS<.) scalar S_new = min(S_new, capS)
            if (S_new<0)  scalar S_new = 0

            scalar pc_i    = A_i / N_t[`i']

            replace S_open = S_eff in `i'
            replace S_end  = S_new in `i'
            replace pc     = pc_i  in `i'

            * ----- Distributional layer -----
            if (dist_mode==1) {
                if (pc_i<=0) {
                    scalar p_tgt = 1
                    scalar p_210 = 1
                }
                else {
                    scalar sigma = sqrt(ln(1 + cv_pc^2))
                    scalar mu    = ln(pc_i) - 0.5*sigma^2
                    scalar z_tgt = (ln(R_tgt[`i']) - mu) / sigma
                    scalar z_210 = (ln(R_fixed)   - mu) / sigma
                    scalar p_tgt = normal(z_tgt)
                    scalar p_210 = normal(z_210)
                }
                replace p_under_target     = p_tgt in `i'
                replace p_under_2100       = p_210 in `i'
                replace share_under_target = p_tgt in `i'
                replace share_under_2100   = p_210 in `i'
            }
            else if (dist_mode==2) {
                scalar hi_cap    = (1 + delta_hi) * R_tgt[`i']
                scalar A_tot     = pc_i * N_t[`i']
                scalar A_hi_need = alpha_hi * N_t[`i'] * hi_cap

                scalar hi_pc = .
                scalar lo_pc = .

                if (A_tot >= A_hi_need) {
                    scalar hi_pc = hi_cap
                    scalar A_lo  = A_tot - A_hi_need
                    scalar lo_pc = A_lo / ((1 - alpha_hi) * N_t[`i'])
                }
                else {
                    scalar hi_pc = A_tot / (alpha_hi * N_t[`i'])
                    scalar lo_pc = 0
                }

                scalar share_tgt = 0
                if (hi_pc < R_tgt[`i']) scalar share_tgt = share_tgt + alpha_hi
                if (lo_pc < R_tgt[`i']) scalar share_tgt = share_tgt + (1 - alpha_hi)

                scalar share_210 = 0
                if (hi_pc < R_fixed)     scalar share_210 = share_210 + alpha_hi
                if (lo_pc < R_fixed)     scalar share_210 = share_210 + (1 - alpha_hi)

                replace p_under_target     = share_tgt in `i'
                replace p_under_2100       = share_210 in `i'
                replace share_under_target = share_tgt in `i'
                replace share_under_2100   = share_210 in `i'
            }

            local S_prev = S_new
        }
    }

    quietly summarize pc, meanonly
    scalar avg_pc = r(mean)
    quietly summarize S_end, meanonly
    scalar avg_S  = r(mean)
    quietly summarize share_under_target, meanonly
    scalar avg_under_tgt = r(mean)
    quietly summarize share_under_2100, meanonly
    scalar avg_under_210 = r(mean)

    post `Hnd_bs' (avg_pc) (avg_S) (avg_under_tgt) (avg_under_210)
}

postclose `Hnd_bs'

use "bs_MAY_18_2025_15_PC_LOSS_EXCEL_PALLETS.dta", clear
display as text "Block bootstrap: median and 95% CI of period mean kcal/person"
centile mean_pc_bs, centile(2.5 50 97.5)

******************************************************************************************************************************************

******************************************************************
* Carryover stock into May (19–31) from Jan–May 18, 
******************************************************************

clear all
set more off
import excel "COGAT_DATA_OCT_2023_SEPTEMBER_2025.xlsx", sheet("COGAT DATA") firstrow clear
keep if date_var > td(31dec2024)
ren INTERNALPRODUCTIONTOTALCALORI calories_internal_production
ren PREWARSTOCKTOTALCALORIES tot_cal_pre_stock
ren IMPORTATIONTOTALCALORIES tot_c
ren POPULATION population
format %15.0g tot_c

generate day = day(date_var)
generate month = month(date_var)
generate year = year(date_var)
gen ym    = ym(year, month)
format ym %tmMonYY
label var ym "Monthly date"

keep date_var day month year population tot_c calories_internal_production

g tot_c_bis = (tot_c*0.85) 
format %15.0g tot_c_bis
egen b = rowtotal(calories_internal_production tot_c_bis)
format %15.0g b

ren b K
set seed 12345

ren date_var DAY
keep if inrange(DAY, td(01jan2025), td(31may2025))

* ---------- CONSTANT PARAMETERS ----------
scalar lambda_in  = 0.000         // inflow leakage
scalar rho_S      = 0.0145         // daily spoilage of stock
scalar capS       = .            // storage capacity ('.' means unlimited)

* Distribution layer
scalar dist_mode  = 1            // 1=lognormal (cv), 2=two-group
scalar cv_pc      = 0.25         // only if dist_mode==1
scalar alpha_hi   = 0.20         // only if dist_mode==2
scalar delta_hi   = 0.20         // only if dist_mode==2

* Bootstrap
scalar L          = 7
scalar B_bs       = 1000

* ---------- DAILY TARGET SERIES (EDIT if May differs) ----------
capture drop R_target
gen double R_target = .
replace R_target = 2000 if inrange(DAY, td(01jan2025), td(19jan2025))
replace R_target = 2300 if inrange(DAY, td(20jan2025), td(31jan2025))
replace R_target = 2300 if inrange(DAY, td(01feb2025), td(28feb2025))
replace R_target = 2100 if inrange(DAY, td(01mar2025), td(14mar2025))
replace R_target = 1995 if inrange(DAY, td(15mar2025), td(28mar2025))
replace R_target = 1890 if inrange(DAY, td(29mar2025), td(31mar2025))
replace R_target = 1890 if inrange(DAY, td(01apr2025), td(11apr2025))
replace R_target = 1785 if inrange(DAY, td(12apr2025), td(25apr2025))
replace R_target = 1680 if inrange(DAY, td(26apr2025), td(30apr2025))
replace R_target = 1407 if inrange(DAY, td(01may2025), td(18may2025))
replace R_target = 1800 if inrange(DAY, td(19may2025), td(31may2025))

assert !missing(R_target)

* ---------- DAILY POPULATION SERIES ----------
capture drop N_t
gen double N_t = .
replace N_t = 2063015.86507594 if inrange(DAY, td(01jan2025), td(31jan2025))  // January
replace N_t = 2048301.93811322 if inrange(DAY, td(01feb2025), td(28feb2025))  // February
replace N_t = 2033692.95442813 if inrange(DAY, td(01mar2025), td(31mar2025))  // March
replace N_t = 2019188.16553987 if inrange(DAY, td(01apr2025), td(30apr2025))  // April
replace N_t = 2004786.82830602 if inrange(DAY, td(01may2025), td(31may2025))  // May (1–31)
assert !missing(N_t)

******************************************************************
* PART A: Compute 18 may stock S0 using ACTUAL Jan–May 18
******************************************************************
preserve
    keep if inrange(DAY, td(01jan2025), td(18may2025))
    sort DAY

    gen double K_adj = K * (1 - lambda_in)
    tempvar S_end
    gen double `S_end' = .

    local S_prev = 0
    quietly {
        forvalues i = 1/`=_N' {
            scalar S_eff  = `S_prev' * (1 - rho_S)
            scalar P_i    = K_adj[`i'] + S_eff

            scalar R_need = R_target[`i'] * N_t[`i']   // daily target × daily pop
            scalar A_i    = min(P_i, R_need)

            scalar S_new  = P_i - A_i
            if (capS<.) scalar S_new = min(S_new, capS)
            if (S_new<0) scalar S_new = 0

            replace `S_end' = S_new in `i'
            local S_prev = S_new
        }
    }

    sort DAY
    scalar S0 = `S_end'[_N]     // carryover stock for May 1
restore

di as txt "Initial carryover stock for May (S0): " as res %15.0gc S0

******************************************************************
* PART B: Bootstrap May 19-31 ONLY, with initial stock = S0
******************************************************************
preserve
    keep if inrange(DAY, td(19may2025), td(31may2025))
    sort DAY

    gen double R_tgt = R_target   // daily targets
    keep DAY K R_tgt N_t
    gen int orig = _n
    tempfile may
    save `may', replace
restore

tempname Hnd_bs
postfile `Hnd_bs' mean_pc_bs mean_S_bs mean_under_target_bs mean_under_2100_bs using ///
    "bs_MAY_31_2025_15_PC_LOSS_EXCEL_PALLETS.dta", replace

use `may', clear
count
scalar T = r(N)

scalar R_fixed = 2100   // fixed humanitarian benchmark

forvalues b = 1/`=scalar(B_bs)' {
    * Moving-block bootstrap indices over May 19–31
    clear
    set obs `=scalar(T)'
    gen int pos = .
    local filled = 0
    while `filled' < T {
        local start = ceil(runiform() * (T - L + 1))
        forvalues j = 0/`=L-1' {
            local idx = `filled' + `j' + 1
            if `idx' <= T replace pos = `start' + `j' in `idx'
        }
        local filled = `filled' + L
    }

    * Map to May series (K, R_tgt, N_t travel with the row)
    rename pos orig
    merge m:1 orig using `may', nogen keep(match)

    drop DAY
    gen double DAY = _n

    gen double K_adj = K * (1 - lambda_in)

    capture drop S_open S_end pc p_under_target p_under_2100 ///
                 share_under_target share_under_2100
    gen double S_open             = .
    gen double S_end              = .
    gen double pc                 = .
    gen double p_under_target     = .
    gen double p_under_2100       = .
    gen double share_under_target = .
    gen double share_under_2100   = .

    * Seed with carryover S0 from Jan–Apr pass
    local S_prev = S0

    quietly {
        forvalues i = 1/`=_N' {
            scalar S_eff   = `S_prev' * (1 - rho_S)
            scalar P_i     = K_adj[`i'] + S_eff

            scalar R_need  = R_tgt[`i'] * N_t[`i']   // daily cap with daily pop
            scalar A_i     = min(P_i, R_need)

            scalar S_new   = P_i - A_i
            if (capS<.) scalar S_new = min(S_new, capS)
            if (S_new<0)  scalar S_new = 0

            scalar pc_i    = A_i / N_t[`i']

            replace S_open = S_eff in `i'
            replace S_end  = S_new in `i'
            replace pc     = pc_i  in `i'

            * ----- Distributional layer -----
            if (dist_mode==1) {
                if (pc_i<=0) {
                    scalar p_tgt = 1
                    scalar p_210 = 1
                }
                else {
                    scalar sigma = sqrt(ln(1 + cv_pc^2))
                    scalar mu    = ln(pc_i) - 0.5*sigma^2
                    scalar z_tgt = (ln(R_tgt[`i']) - mu) / sigma
                    scalar z_210 = (ln(R_fixed)   - mu) / sigma
                    scalar p_tgt = normal(z_tgt)
                    scalar p_210 = normal(z_210)
                }
                replace p_under_target     = p_tgt in `i'
                replace p_under_2100       = p_210 in `i'
                replace share_under_target = p_tgt in `i'
                replace share_under_2100   = p_210 in `i'
            }
            else if (dist_mode==2) {
                scalar hi_cap    = (1 + delta_hi) * R_tgt[`i']
                scalar A_tot     = pc_i * N_t[`i']
                scalar A_hi_need = alpha_hi * N_t[`i'] * hi_cap

                scalar hi_pc = .
                scalar lo_pc = .

                if (A_tot >= A_hi_need) {
                    scalar hi_pc = hi_cap
                    scalar A_lo  = A_tot - A_hi_need
                    scalar lo_pc = A_lo / ((1 - alpha_hi) * N_t[`i'])
                }
                else {
                    scalar hi_pc = A_tot / (alpha_hi * N_t[`i'])
                    scalar lo_pc = 0
                }

                scalar share_tgt = 0
                if (hi_pc < R_tgt[`i']) scalar share_tgt = share_tgt + alpha_hi
                if (lo_pc < R_tgt[`i']) scalar share_tgt = share_tgt + (1 - alpha_hi)

                scalar share_210 = 0
                if (hi_pc < R_fixed)     scalar share_210 = share_210 + alpha_hi
                if (lo_pc < R_fixed)     scalar share_210 = share_210 + (1 - alpha_hi)

                replace p_under_target     = share_tgt in `i'
                replace p_under_2100       = share_210 in `i'
                replace share_under_target = share_tgt in `i'
                replace share_under_2100   = share_210 in `i'
            }

            local S_prev = S_new
        }
    }

    quietly summarize pc, meanonly
    scalar avg_pc = r(mean)
    quietly summarize S_end, meanonly
    scalar avg_S  = r(mean)
    quietly summarize share_under_target, meanonly
    scalar avg_under_tgt = r(mean)
    quietly summarize share_under_2100, meanonly
    scalar avg_under_210 = r(mean)

    post `Hnd_bs' (avg_pc) (avg_S) (avg_under_tgt) (avg_under_210)
}

postclose `Hnd_bs'

/*** Outputs:
- bs_1_MAY_18_MAY.dta with variables:
    mean_pc_bs              = average May (1–18) per-capita intake
    mean_S_bs               = average May end-of-day stock
    mean_under_target_bs    = avg daily share < daily target
    mean_under_2100_bs      = avg daily share < 2100
- Carryover S0 computed from ACTUAL Jan–Apr with daily pop & targets.
***/
u "bs_MAY_31_2025_15_PC_LOSS_EXCEL_PALLETS.dta", clear
display as text "Block bootstrap: median and 95% CI of period mean kcal/person"
centile mean_pc_bs, centile(2.5 50 97.5)

******************************************************************
* JUNE 2025
******************************************************************/

import excel "COGAT_DATA_OCT_2023_SEPTEMBER_2025.xlsx", sheet("COGAT DATA") firstrow clear
keep if date_var > td(31dec2024)
ren INTERNALPRODUCTIONTOTALCALORI calories_internal_production
ren PREWARSTOCKTOTALCALORIES tot_cal_pre_stock
ren IMPORTATIONTOTALCALORIES tot_c
ren POPULATION population
format %15.0g tot_c

generate day = day(date_var)
generate month = month(date_var)
generate year = year(date_var)
gen ym    = ym(year, month)
format ym %tmMonYY
label var ym "Monthly date"

keep date_var day month year population tot_c calories_internal_production

g tot_c_bis = (tot_c)*0.85
format %15.0g tot_c_bis
egen b = rowtotal(calories_internal_production tot_c_bis)
format %15.0g b

ren b K
set seed 12345

ren date_var DAY
keep if inrange(DAY, td(01jan2025), td(30jun2025))

* ---------- CONSTANT PARAMETERS ----------
scalar lambda_in  = 0.00         // inflow leakage
scalar rho_S      = 0.0225        // daily spoilage of stock
scalar capS       = .            // storage capacity ('.' means unlimited)

* Distribution layer
scalar dist_mode  = 1            // 1=lognormal (cv), 2=two-group
scalar cv_pc      = 0.25         // only if dist_mode==1
scalar alpha_hi   = 0.20         // only if dist_mode==2
scalar delta_hi   = 0.20         // only if dist_mode==2

* Bootstrap
scalar L          = 7
scalar B_bs       = 1000

* ---------- DAILY TARGET SERIES (EDIT if May differs) ----------
capture drop R_target
gen double R_target = .
replace R_target = 2000 if inrange(DAY, td(01jan2025), td(19jan2025))
replace R_target = 2300 if inrange(DAY, td(20jan2025), td(31jan2025))
replace R_target = 2300 if inrange(DAY, td(01feb2025), td(28feb2025))
replace R_target = 2100 if inrange(DAY, td(01mar2025), td(14mar2025))
replace R_target = 1995 if inrange(DAY, td(15mar2025), td(28mar2025))
replace R_target = 1890 if inrange(DAY, td(29mar2025), td(31mar2025))
replace R_target = 1890 if inrange(DAY, td(01apr2025), td(11apr2025))
replace R_target = 1785 if inrange(DAY, td(12apr2025), td(25apr2025))
replace R_target = 1680 if inrange(DAY, td(26apr2025), td(30apr2025))
replace R_target = 1680 if inrange(DAY, td(01may2025), td(09may2025))
replace R_target = 1407 if inrange(DAY, td(10may2025), td(18may2025))
replace R_target = 1800 if inrange(DAY, td(19may2025), td(31may2025))
replace R_target = 2100 if inrange(DAY, td(01jun2025), td(30jun2025))
assert !missing(R_target)

* ---------- DAILY POPULATION SERIES ----------
capture drop N_t
gen double N_t = .
replace N_t = 2063015.86507594 if inrange(DAY, td(01jan2025), td(31jan2025))  // January
replace N_t = 2048301.93811322 if inrange(DAY, td(01feb2025), td(28feb2025))  // February
replace N_t = 2033692.95442813 if inrange(DAY, td(01mar2025), td(31mar2025))  // March
replace N_t = 2019188.16553987 if inrange(DAY, td(01apr2025), td(30apr2025))  // April
replace N_t = 2004786.82830602 if inrange(DAY, td(01may2025), td(31may2025))  // May 
replace N_t = 1990488.20488441 if inrange(DAY, td(01jun2025), td(30jun2025))  // June
assert !missing(N_t)

******************************************************************
* PART A: Compute end-of-April stock S0 using ACTUAL Jan–Apr
******************************************************************
preserve
    keep if inrange(DAY, td(01jan2025), td(30may2025))
    sort DAY

    gen double K_adj = K * (1 - lambda_in)
    tempvar S_end
    gen double `S_end' = .

    local S_prev = 0
    quietly {
        forvalues i = 1/`=_N' {
            scalar S_eff  = `S_prev' * (1 - rho_S)
            scalar P_i    = K_adj[`i'] + S_eff

            scalar R_need = R_target[`i'] * N_t[`i']   // daily target × daily pop
            scalar A_i    = min(P_i, R_need)

            scalar S_new  = P_i - A_i
            if (capS<.) scalar S_new = min(S_new, capS)
            if (S_new<0) scalar S_new = 0

            replace `S_end' = S_new in `i'
            local S_prev = S_new
        }
    }

    sort DAY
    scalar S0 = `S_end'[_N]     // carryover stock for May 1
restore

di as txt "Initial carryover stock for June (S0): " as res %15.0gc S0

******************************************************************
* PART B: Bootstrap June ONLY, with initial stock = S0
******************************************************************
preserve
    keep if inrange(DAY, td(01jun2025), td(30jun2025))
    sort DAY

    gen double R_tgt = R_target   // daily targets
    keep DAY K R_tgt N_t
    gen int orig = _n
    tempfile june
    save `june', replace
restore

tempname Hnd_bs
postfile `Hnd_bs' mean_pc_bs mean_S_bs mean_under_target_bs mean_under_2100_bs using ///
    "bs_JUNE_2025_15_PC_LOSS_EXCEL_PALLETS.dta", replace

use `june', clear
count
scalar T = r(N)

scalar R_fixed = 2100   // fixed humanitarian benchmark

forvalues b = 1/`=scalar(B_bs)' {
    * Moving-block bootstrap indices over May 19–31
    clear
    set obs `=scalar(T)'
    gen int pos = .
    local filled = 0
    while `filled' < T {
        local start = ceil(runiform() * (T - L + 1))
        forvalues j = 0/`=L-1' {
            local idx = `filled' + `j' + 1
            if `idx' <= T replace pos = `start' + `j' in `idx'
        }
        local filled = `filled' + L
    }

    * Map to May series (K, R_tgt, N_t travel with the row)
    rename pos orig
    merge m:1 orig using `june', nogen keep(match)

    drop DAY
    gen double DAY = _n

    gen double K_adj = K * (1 - lambda_in)

    capture drop S_open S_end pc p_under_target p_under_2100 ///
                 share_under_target share_under_2100
    gen double S_open             = .
    gen double S_end              = .
    gen double pc                 = .
    gen double p_under_target     = .
    gen double p_under_2100       = .
    gen double share_under_target = .
    gen double share_under_2100   = .

    * Seed with carryover S0 from Jan–Apr pass
    local S_prev = S0

    quietly {
        forvalues i = 1/`=_N' {
            scalar S_eff   = `S_prev' * (1 - rho_S)
            scalar P_i     = K_adj[`i'] + S_eff

            scalar R_need  = R_tgt[`i'] * N_t[`i']   // daily cap with daily pop
            scalar A_i     = min(P_i, R_need)

            scalar S_new   = P_i - A_i
            if (capS<.) scalar S_new = min(S_new, capS)
            if (S_new<0)  scalar S_new = 0

            scalar pc_i    = A_i / N_t[`i']

            replace S_open = S_eff in `i'
            replace S_end  = S_new in `i'
            replace pc     = pc_i  in `i'

            * ----- Distributional layer -----
            if (dist_mode==1) {
                if (pc_i<=0) {
                    scalar p_tgt = 1
                    scalar p_210 = 1
                }
                else {
                    scalar sigma = sqrt(ln(1 + cv_pc^2))
                    scalar mu    = ln(pc_i) - 0.5*sigma^2
                    scalar z_tgt = (ln(R_tgt[`i']) - mu) / sigma
                    scalar z_210 = (ln(R_fixed)   - mu) / sigma
                    scalar p_tgt = normal(z_tgt)
                    scalar p_210 = normal(z_210)
                }
                replace p_under_target     = p_tgt in `i'
                replace p_under_2100       = p_210 in `i'
                replace share_under_target = p_tgt in `i'
                replace share_under_2100   = p_210 in `i'
            }
            else if (dist_mode==2) {
                scalar hi_cap    = (1 + delta_hi) * R_tgt[`i']
                scalar A_tot     = pc_i * N_t[`i']
                scalar A_hi_need = alpha_hi * N_t[`i'] * hi_cap

                scalar hi_pc = .
                scalar lo_pc = .

                if (A_tot >= A_hi_need) {
                    scalar hi_pc = hi_cap
                    scalar A_lo  = A_tot - A_hi_need
                    scalar lo_pc = A_lo / ((1 - alpha_hi) * N_t[`i'])
                }
                else {
                    scalar hi_pc = A_tot / (alpha_hi * N_t[`i'])
                    scalar lo_pc = 0
                }

                scalar share_tgt = 0
                if (hi_pc < R_tgt[`i']) scalar share_tgt = share_tgt + alpha_hi
                if (lo_pc < R_tgt[`i']) scalar share_tgt = share_tgt + (1 - alpha_hi)

                scalar share_210 = 0
                if (hi_pc < R_fixed)     scalar share_210 = share_210 + alpha_hi
                if (lo_pc < R_fixed)     scalar share_210 = share_210 + (1 - alpha_hi)

                replace p_under_target     = share_tgt in `i'
                replace p_under_2100       = share_210 in `i'
                replace share_under_target = share_tgt in `i'
                replace share_under_2100   = share_210 in `i'
            }

            local S_prev = S_new
        }
    }

    quietly summarize pc, meanonly
    scalar avg_pc = r(mean)
    quietly summarize S_end, meanonly
    scalar avg_S  = r(mean)
    quietly summarize share_under_target, meanonly
    scalar avg_under_tgt = r(mean)
    quietly summarize share_under_2100, meanonly
    scalar avg_under_210 = r(mean)

    post `Hnd_bs' (avg_pc) (avg_S) (avg_under_tgt) (avg_under_210)
}

postclose `Hnd_bs'

/*** Outputs:
- bs_1_MAY_18_MAY.dta with variables:
    mean_pc_bs              = average May (1–18) per-capita intake
    mean_S_bs               = average May end-of-day stock
    mean_under_target_bs    = avg daily share < daily target
    mean_under_2100_bs      = avg daily share < 2100
- Carryover S0 computed from ACTUAL Jan–Apr with daily pop & targets.
***/

use "bs_JUNE_2025_15_PC_LOSS_EXCEL_PALLETS.dta", clear
display as text "Block bootstrap: median and 95% CI of period mean kcal/person"
centile mean_pc_bs, centile(2.5 50 97.5)

******************************************************************
* JULY 2025
******************************************************************/

clear all
set more off
set seed 12345

import excel "COGAT_DATA_OCT_2023_SEPTEMBER_2025.xlsx", sheet("COGAT DATA") firstrow clear
keep if date_var > td(31dec2024)
ren INTERNALPRODUCTIONTOTALCALORI calories_internal_production
ren PREWARSTOCKTOTALCALORIES tot_cal_pre_stock
ren IMPORTATIONTOTALCALORIES tot_c
ren POPULATION population
format %15.0g tot_c

generate day = day(date_var)
generate month = month(date_var)
generate year = year(date_var)
gen ym    = ym(year, month)
format ym %tmMonYY
label var ym "Monthly date"

keep date_var day month year population tot_c calories_internal_production

g tot_c_bis = (tot_c)*0.85
format %15.0g tot_c_bis
egen b = rowtotal(calories_internal_production tot_c_bis)
format %15.0g b

ren b K
set seed 12345

ren date_var DAY
keep if inrange(DAY, td(01jan2025), td(31jul2025))

* ---------- CONSTANT PARAMETERS ----------
scalar lambda_in  = 0.000         // inflow leakage
scalar rho_S      = 0.0092         // daily spoilage of stock
scalar capS       = .            // storage capacity ('.' means unlimited)

* Distribution layer
scalar dist_mode  = 1            // 1=lognormal (cv), 2=two-group
scalar cv_pc      = 0.25         // only if dist_mode==1
scalar alpha_hi   = 0.20         // only if dist_mode==2
scalar delta_hi   = 0.20         // only if dist_mode==2

* Bootstrap
scalar L          = 7
scalar B_bs       = 1000

* ---------- DAILY TARGET SERIES (EDIT if May differs) ----------
capture drop R_target
gen double R_target = .
replace R_target = 2000 if inrange(DAY, td(01jan2025), td(19jan2025))
replace R_target = 2300 if inrange(DAY, td(20jan2025), td(31jan2025))
replace R_target = 2300 if inrange(DAY, td(01feb2025), td(28feb2025))
replace R_target = 2100 if inrange(DAY, td(01mar2025), td(14mar2025))
replace R_target = 1995 if inrange(DAY, td(15mar2025), td(28mar2025))
replace R_target = 1890 if inrange(DAY, td(29mar2025), td(31mar2025))
replace R_target = 1890 if inrange(DAY, td(01apr2025), td(11apr2025))
replace R_target = 1785 if inrange(DAY, td(12apr2025), td(25apr2025))
replace R_target = 1680 if inrange(DAY, td(26apr2025), td(30apr2025))
replace R_target = 1680 if inrange(DAY, td(01may2025), td(09may2025))
replace R_target = 1407 if inrange(DAY, td(10may2025), td(18may2025))
replace R_target = 1800 if inrange(DAY, td(19may2025), td(31may2025))
replace R_target = 2100 if inrange(DAY, td(01jun2025), td(30jun2025))
replace R_target = 2100 if inrange(DAY, td(01jul2025), td(31jul2025))
assert !missing(R_target)

* ---------- DAILY POPULATION SERIES ----------
capture drop N_t
gen double N_t = .
replace N_t = 2063015.86507594 if inrange(DAY, td(01jan2025), td(31jan2025))  // January
replace N_t = 2048301.93811322 if inrange(DAY, td(01feb2025), td(28feb2025))  // February
replace N_t = 2033692.95442813 if inrange(DAY, td(01mar2025), td(31mar2025))  // March
replace N_t = 2019188.16553987 if inrange(DAY, td(01apr2025), td(30apr2025))  // April
replace N_t = 2004786.82830602 if inrange(DAY, td(01may2025), td(31may2025))  // May (1–18)
replace N_t = 1990488.20488441 if inrange(DAY, td(01jun2025), td(30jun2025))  // May (1–18)
replace N_t = 1976291.56269536 if inrange(DAY, td(01jul2025), td(31jul2025))  // May (1–18)
assert !missing(N_t)

******************************************************************
* PART A: Compute end-of-April stock S0 using ACTUAL Jan–June
******************************************************************
preserve
    keep if inrange(DAY, td(01jan2025), td(30jun2025))
    sort DAY

    gen double K_adj = K * (1 - lambda_in)
    tempvar S_end
    gen double `S_end' = .

    local S_prev = 105.78543
    quietly {
        forvalues i = 1/`=_N' {
            scalar S_eff  = `S_prev' * (1 - rho_S)
            scalar P_i    = K_adj[`i'] + S_eff

            scalar R_need = R_target[`i'] * N_t[`i']   // daily target × daily pop
            scalar A_i    = min(P_i, R_need)

            scalar S_new  = P_i - A_i
            if (capS<.) scalar S_new = min(S_new, capS)
            if (S_new<0) scalar S_new = 0

            replace `S_end' = S_new in `i'
            local S_prev = S_new
        }
    }

    sort DAY
    scalar S0 = `S_end'[_N]     // carryover stock for May 1
restore

di as txt "Initial carryover stock for July (S0): " as res %15.0gc S0

******************************************************************
* PART B: Bootstrap May 1–18 ONLY, with initial stock = S0
******************************************************************
preserve
    keep if inrange(DAY, td(01jul2025), td(31jul2025))
    sort DAY

    gen double R_tgt = R_target   // daily targets
    keep DAY K R_tgt N_t
    gen int orig = _n
    tempfile may
    save `may', replace
restore

tempname Hnd_bs
postfile `Hnd_bs' mean_pc_bs mean_S_bs mean_under_target_bs mean_under_2100_bs using ///
    "bs_JULY_2025_15_PC_LOSS_EXCEL_PALLETS.dta", replace

use `may', clear
count
scalar T = r(N)

scalar R_fixed = 2100   // fixed humanitarian benchmark

forvalues b = 1/`=scalar(B_bs)' {
    * Moving-block bootstrap indices over May 19–31
    clear
    set obs `=scalar(T)'
    gen int pos = .
    local filled = 0
    while `filled' < T {
        local start = ceil(runiform() * (T - L + 1))
        forvalues j = 0/`=L-1' {
            local idx = `filled' + `j' + 1
            if `idx' <= T replace pos = `start' + `j' in `idx'
        }
        local filled = `filled' + L
    }

    * Map to May series (K, R_tgt, N_t travel with the row)
    rename pos orig
    merge m:1 orig using `may', nogen keep(match)

    drop DAY
    gen double DAY = _n

    gen double K_adj = K * (1 - lambda_in)

    capture drop S_open S_end pc p_under_target p_under_2100 ///
                 share_under_target share_under_2100
    gen double S_open             = .
    gen double S_end              = .
    gen double pc                 = .
    gen double p_under_target     = .
    gen double p_under_2100       = .
    gen double share_under_target = .
    gen double share_under_2100   = .

    * Seed with carryover S0 from Jan–Apr pass
    local S_prev = S0

    quietly {
        forvalues i = 1/`=_N' {
            scalar S_eff   = `S_prev' * (1 - rho_S)
            scalar P_i     = K_adj[`i'] + S_eff

            scalar R_need  = R_tgt[`i'] * N_t[`i']   // daily cap with daily pop
            scalar A_i     = min(P_i, R_need)

            scalar S_new   = P_i - A_i
            if (capS<.) scalar S_new = min(S_new, capS)
            if (S_new<0)  scalar S_new = 0

            scalar pc_i    = A_i / N_t[`i']

            replace S_open = S_eff in `i'
            replace S_end  = S_new in `i'
            replace pc     = pc_i  in `i'

            * ----- Distributional layer -----
            if (dist_mode==1) {
                if (pc_i<=0) {
                    scalar p_tgt = 1
                    scalar p_210 = 1
                }
                else {
                    scalar sigma = sqrt(ln(1 + cv_pc^2))
                    scalar mu    = ln(pc_i) - 0.5*sigma^2
                    scalar z_tgt = (ln(R_tgt[`i']) - mu) / sigma
                    scalar z_210 = (ln(R_fixed)   - mu) / sigma
                    scalar p_tgt = normal(z_tgt)
                    scalar p_210 = normal(z_210)
                }
                replace p_under_target     = p_tgt in `i'
                replace p_under_2100       = p_210 in `i'
                replace share_under_target = p_tgt in `i'
                replace share_under_2100   = p_210 in `i'
            }
            else if (dist_mode==2) {
                scalar hi_cap    = (1 + delta_hi) * R_tgt[`i']
                scalar A_tot     = pc_i * N_t[`i']
                scalar A_hi_need = alpha_hi * N_t[`i'] * hi_cap

                scalar hi_pc = .
                scalar lo_pc = .

                if (A_tot >= A_hi_need) {
                    scalar hi_pc = hi_cap
                    scalar A_lo  = A_tot - A_hi_need
                    scalar lo_pc = A_lo / ((1 - alpha_hi) * N_t[`i'])
                }
                else {
                    scalar hi_pc = A_tot / (alpha_hi * N_t[`i'])
                    scalar lo_pc = 0
                }

                scalar share_tgt = 0
                if (hi_pc < R_tgt[`i']) scalar share_tgt = share_tgt + alpha_hi
                if (lo_pc < R_tgt[`i']) scalar share_tgt = share_tgt + (1 - alpha_hi)

                scalar share_210 = 0
                if (hi_pc < R_fixed)     scalar share_210 = share_210 + alpha_hi
                if (lo_pc < R_fixed)     scalar share_210 = share_210 + (1 - alpha_hi)

                replace p_under_target     = share_tgt in `i'
                replace p_under_2100       = share_210 in `i'
                replace share_under_target = share_tgt in `i'
                replace share_under_2100   = share_210 in `i'
            }

            local S_prev = S_new
        }
    }

    quietly summarize pc, meanonly
    scalar avg_pc = r(mean)
    quietly summarize S_end, meanonly
    scalar avg_S  = r(mean)
    quietly summarize share_under_target, meanonly
    scalar avg_under_tgt = r(mean)
    quietly summarize share_under_2100, meanonly
    scalar avg_under_210 = r(mean)

    post `Hnd_bs' (avg_pc) (avg_S) (avg_under_tgt) (avg_under_210)
}

postclose `Hnd_bs'

/*** Outputs:
- bs_1_MAY_18_MAY.dta with variables:
    mean_pc_bs              = average May (1–18) per-capita intake
    mean_S_bs               = average May end-of-day stock
    mean_under_target_bs    = avg daily share < daily target
    mean_under_2100_bs      = avg daily share < 2100
- Carryover S0 computed from ACTUAL Jan–Apr with daily pop & targets.
***/

use "bs_JULY_2025_15_PC_LOSS_EXCEL_PALLETS.dta", clear
display as text "Block bootstrap: median and 95% CI of period mean kcal/person"
centile mean_pc_bs, centile(2.5 50 97.5)

*******************************************************
*  August 2025
*******************************************************
import excel "COGAT_DATA_OCT_2023_SEPTEMBER_2025.xlsx", sheet("COGAT DATA") firstrow clear
keep if date_var > td(31dec2024)
ren INTERNALPRODUCTIONTOTALCALORI calories_internal_production
ren PREWARSTOCKTOTALCALORIES tot_cal_pre_stock
ren IMPORTATIONTOTALCALORIES tot_c
ren POPULATION population
format %15.0g tot_c

generate day = day(date_var)
generate month = month(date_var)
generate year = year(date_var)
gen ym    = ym(year, month)
format ym %tmMonYY
label var ym "Monthly date"

keep date_var day month year population tot_c calories_internal_production

g tot_c_bis = (tot_c)*0.85
format %15.0g tot_c_bis
egen b = rowtotal(calories_internal_production tot_c_bis)
format %15.0g b

ren b K
set seed 12345

ren date_var DAY
keep if inrange(DAY, td(01aug2025), td(31aug2025))


* ==== CONSTANT PARAMETERS ====
scalar lambda_in  = 0.000          // inflow leakage
scalar rho_S      = 0.0092        // daily spoilage of stock
scalar capS       = .             // no stock capacity limit
scalar dist_mode  = 1             // use lognormal distribution
scalar cv_pc      = 0.25          // coefficient of variation (inequality)
scalar L          = 7             // block length (days)
scalar B_bs       = 1000          // bootstrap replications

* ==== Thresholds (kcal/person/day) ====
scalar R_mod_def = 1800           // moderate deficiency
scalar R_min_req = 2100           // minimum requirement
scalar R_comf    = 2500           // comfortable intake

* ==== Daily population and target ====
gen double R_target = 2100
gen double N_t = 1960812.77029021   // August population estimate


******************************************************************
*  STEP 1 – Compute carry-over stock S0 up to 1 August
******************************************************************
preserve
    keep if inrange(DAY, td(01jan2025), td(31jul2025))
    sort DAY
    gen double K_adj = K * (1 - lambda_in)
    tempvar S_end
    gen double `S_end' = .
    local S_prev = 0

    quietly {
        forvalues i = 1/`=_N' {
            scalar S_eff = `S_prev' * (1 - rho_S)
            scalar P_i   = K_adj[`i'] + S_eff
            scalar R_need = 2100 * N_t[1]
            scalar A_i   = min(P_i, R_need)
            scalar S_new = P_i - A_i
            if (capS < .) scalar S_new = min(S_new, capS)
            if (S_new < 0) scalar S_new = 0
            replace `S_end' = S_new in `i'
            local S_prev = S_new
        }
    }
    sort DAY
    scalar S0 = `S_end'[_N]
restore

di as txt "Initial carry-over stock for August (S0): " as res %15.0gc S0


******************************************************************
*  STEP 2 – Prepare bootstrap sample for August
******************************************************************
tempfile aug
keep if inrange(DAY, td(01aug2025), td(31aug2025))
keep DAY K R_target N_t
gen int orig = _n
save `aug', replace


******************************************************************
*  STEP 3 – Bootstrap simulation with inequality layer
******************************************************************
tempname Hnd_bs
postfile `Hnd_bs' mean_pc_bs mean_S_bs share_below_1800 share_below_2100 share_above_2500 using ///
    "bs_AUGUST_2025_15_PC_LOSS_EXCEL_PALLETS.dta", replace

scalar R_fixed = 2100

forvalues b = 1/`=scalar(B_bs)' {
    use `aug', clear
    sort orig

    * --- Compute inflow uncertainty based on relative inflow level ---
    summarize K, meanonly
    scalar K_mean = r(mean)
    gen double relK = K / K_mean
    gen double inflow_sd = cond(relK < 0.5, 0.15, cond(relK < 1, 0.10, 0.05))

    * --- Apply stochastic inflow noise (mean bias -0.05) ---
    gen double K_adj = K * (1 - lambda_in) * (1 + rnormal(-0.05, inflow_sd))

    * --- Initialize variables ---
    gen double A_i   = .
    gen double S_end = .
    gen double A_pc  = .
    local S_prev = S0

    quietly {
        forvalues i = 1/`=_N' {
            scalar S_eff = `S_prev' * (1 - rho_S)
            scalar P_i   = K_adj[`i'] + S_eff
            scalar R_need = R_target[`i'] * N_t[`i']
            scalar A_t   = min(P_i, R_need)
            scalar S_new = P_i - A_t
            if (capS < .) scalar S_new = min(S_new, capS)
            if (S_new < 0) scalar S_new = 0
            replace A_i   = A_t in `i'
            replace S_end = S_new in `i'
            replace A_pc  = A_t / N_t[`i'] in `i'
            local S_prev = S_new
        }
    }

    * --- Apply inequality layer (lognormal distribution) ---
    gen double sigma = sqrt(ln(1 + cv_pc^2))
    gen double mu    = ln(A_pc) - 0.5 * sigma^2
    gen double A_pc_ind = exp(rnormal(mu, sigma))   // individual-level calories

    * --- Compute shares under/above thresholds ---
    gen double below_1800 = (A_pc_ind < R_mod_def)
    gen double below_2100 = (A_pc_ind < R_min_req)
    gen double above_2500 = (A_pc_ind > R_comf)

    quietly summarize A_pc_ind, meanonly
    scalar avg_pc = r(mean)
    quietly summarize S_end, meanonly
    scalar avg_S  = r(mean)
    quietly summarize below_1800, meanonly
    scalar share1800 = r(mean)
    quietly summarize below_2100, meanonly
    scalar share2100 = r(mean)
    quietly summarize above_2500, meanonly
    scalar share2500 = r(mean)

    post `Hnd_bs' (avg_pc) (avg_S) (share1800) (share2100) (share2500)
}

postclose `Hnd_bs'


******************************************************************
*  STEP 4 – Summarize bootstrap results and compute CI
******************************************************************
use "bs_AUGUST_2025_15_PC_LOSS_EXCEL_PALLETS.dta", clear
display as text "Block bootstrap: median and 95% CI of period mean kcal/person"
centile mean_pc_bs, centile(2.5 50 97.5)


*******************************************************
*  SEPTEMBER 2025
*******************************************************
import excel "COGAT_DATA_OCT_2023_SEPTEMBER_2025.xlsx", sheet("COGAT DATA") firstrow clear
keep if date_var > td(31dec2024)
ren INTERNALPRODUCTIONTOTALCALORI calories_internal_production
ren PREWARSTOCKTOTALCALORIES tot_cal_pre_stock
ren IMPORTATIONTOTALCALORIES tot_c
ren POPULATION population
format %15.0g tot_c

generate day = day(date_var)
generate month = month(date_var)
generate year = year(date_var)
gen ym    = ym(year, month)
format ym %tmMonYY
label var ym "Monthly date"

keep date_var day month year population tot_c calories_internal_production

g tot_c_bis = (tot_c)*0.85
format %15.0g tot_c_bis
egen b = rowtotal(calories_internal_production tot_c_bis)
format %15.0g b

ren b K
set seed 12345

ren date_var DAY
keep if inrange(DAY, td(01sep2025), td(30sep2025))


* ==== CONSTANT PARAMETERS ====
scalar lambda_in  = 0.000          // inflow leakage
scalar rho_S      = 0.0092        // daily spoilage of stock
scalar capS       = .             // no stock capacity limit
scalar dist_mode  = 1             // use lognormal distribution
scalar cv_pc      = 0.25          // coefficient of variation of intake (inequality)
scalar L          = 7             // block length (days)
scalar B_bs       = 1000          // bootstrap replications

* ==== Thresholds (kcal/person/day) ====
scalar R_mod_def = 1800           // moderate deficiency
scalar R_min_req = 2100           // minimum requirement
scalar R_comf    = 2500           // comfortable intake

* ==== Daily population and target ====
gen double R_target = 2100
gen double N_t = 1945455.21152226


******************************************************************
*  STEP 1 – Compute carry-over stock S0 up to 1 September
******************************************************************
preserve
    keep if inrange(DAY, td(01jan2025), td(31aug2025))
    sort DAY
    gen double K_adj = K * (1 - lambda_in)
    tempvar S_end
    gen double `S_end' = .
    local S_prev = 0

    quietly {
        forvalues i = 1/`=_N' {
            scalar S_eff = `S_prev' * (1 - rho_S)
            scalar P_i   = K_adj[`i'] + S_eff
            scalar R_need = 2100 * N_t[1]
            scalar A_i   = min(P_i, R_need)
            scalar S_new = P_i - A_i
            if (capS < .) scalar S_new = min(S_new, capS)
            if (S_new < 0) scalar S_new = 0
            replace `S_end' = S_new in `i'
            local S_prev = S_new
        }
    }
    sort DAY
    scalar S0 = `S_end'[_N]
restore

di as txt "Initial carry-over stock for September (S0): " as res %15.0gc S0


******************************************************************
*  STEP 2 – Prepare bootstrap sample for September
******************************************************************
tempfile sept
keep if inrange(DAY, td(01sep2025), td(30sep2025))
keep DAY K R_target N_t
gen int orig = _n
save `sept', replace


******************************************************************
*  STEP 3 – Bootstrap simulation with inequality layer
******************************************************************
tempname Hnd_bs
postfile `Hnd_bs' mean_pc_bs mean_S_bs share_below_1800 share_below_2100 share_above_2500 using ///
    "bs_SEPTEMBER_2025_15_PC_LOSS_EXCEL_PALLETS.dta", replace

scalar R_fixed = 2100

forvalues b = 1/`=scalar(B_bs)' {
    use `sept', clear
    sort orig

    * --- Compute inflow uncertainty based on relative inflow level ---
    summarize K, meanonly
    scalar K_mean = r(mean)
    gen double relK = K / K_mean
    gen double inflow_sd = cond(relK < 0.5, 0.15, cond(relK < 1, 0.10, 0.05))

    * --- Apply stochastic inflow noise (mean bias -0.05) ---
    gen double K_adj = K * (1 - lambda_in) * (1 + rnormal(-0.05, inflow_sd))

    * --- Initialize variables ---
    gen double A_i   = .
    gen double S_end = .
    gen double A_pc  = .
    local S_prev = S0

    quietly {
        forvalues i = 1/`=_N' {
            scalar S_eff = `S_prev' * (1 - rho_S)
            scalar P_i   = K_adj[`i'] + S_eff
            scalar R_need = R_target[`i'] * N_t[`i']
            scalar A_t   = min(P_i, R_need)
            scalar S_new = P_i - A_t
            if (capS < .) scalar S_new = min(S_new, capS)
            if (S_new < 0) scalar S_new = 0
            replace A_i   = A_t in `i'
            replace S_end = S_new in `i'
            replace A_pc  = A_t / N_t[`i'] in `i'
            local S_prev = S_new
        }
    }

    * --- Apply inequality layer (lognormal distribution) ---
    gen double sigma = sqrt(ln(1 + cv_pc^2))
    gen double mu    = ln(A_pc) - 0.5 * sigma^2
    gen double A_pc_ind = exp(rnormal(mu, sigma))   // individual-level calories

    * --- Compute shares under/above thresholds ---
    gen double below_1800 = (A_pc_ind < R_mod_def)
    gen double below_2100 = (A_pc_ind < R_min_req)
    gen double above_2500 = (A_pc_ind > R_comf)

    quietly summarize A_pc_ind, meanonly
    scalar avg_pc = r(mean)
    quietly summarize S_end, meanonly
    scalar avg_S  = r(mean)
    quietly summarize below_1800, meanonly
    scalar share1800 = r(mean)
    quietly summarize below_2100, meanonly
    scalar share2100 = r(mean)
    quietly summarize above_2500, meanonly
    scalar share2500 = r(mean)

    post `Hnd_bs' (avg_pc) (avg_S) (share1800) (share2100) (share2500)
}

postclose `Hnd_bs'

******************************************************************
*  STEP 4 – Summarize bootstrap results and compute CI
******************************************************************
use "bs_SEPTEMBER_2025_15_PC_LOSS_EXCEL_PALLETS.dta", clear
display as text "Block bootstrap: median and 95% CI of period mean kcal/person"
centile mean_pc_bs, centile(2.5 50 97.5)


*****************************************************************
*  MERGE THE TWO PERIOD OF MAY
******************************************************************

use "bs_MAY_18_2025_15_PC_LOSS_EXCEL_PALLETS.dta", clear
tempfile may1 
g b = _n
sa `may1'
use "bs_MAY_31_2025_15_PC_LOSS_EXCEL_PALLETS.dta", clear
tempfile may2
g b = _n
sa `may2'

u `may1'
append using `may2'
collapse(mean) mean_pc_bs mean_S_bs mean_under_target_bs mean_under_2100_bs,by(b)
drop b
save "bs_MAY_2025_15_PC_LOSS_EXCEL_PALLETS.dta", replace

******************************************************************
*  POST-LOOP SUMMARY
******************************************************************
local months "JANUARY FEBRUARY MARCH APRIL MAY JUNE JULY AUGUST SEPTEMBER"
local years  "2025 2025 2025 2025 2025 2025 2025 2025 2025"

tempfile results
save `results', emptyok replace

forvalues i = 1/9 {
    local m : word `i' of `months'
    local y : word `i' of `years'

    di "Summarizing month: `m' `y'"
    use "bs_`m'_`y'_15_PC_LOSS_EXCEL_PALLETS.dta", clear

    quietly centile mean_pc_bs, centile(2.5 50 97.5)
	return list
    scalar p2_5 = r(c_1)
    scalar p50  = r(c_2)
    scalar p97_5 = r(c_3)

    ci mean mean_pc_bs
	return list
    scalar mean = r(mean)
    scalar ll   = r(lb)
    scalar ul   = r(ub)


    clear
    set obs 1
    gen year  = `y'
    gen month = `i' 

    gen mean_pc_bs_p2_5  = p2_5
    gen mean_pc_bs_p50   = p50
    gen mean_pc_bs_p97_5 = p97_5
    gen mean_pc_bs_mean  = mean
    gen ci_lower         = ll
    gen ci_upper         = ul

    append using `results'
    save `results', replace
}
drop mean_pc_bs mean_S_bs mean_under_target_bs mean_under_2100_bs
drop if month == .
sort year month
save "bs_JANUARY_SEPTEMBER_2025_15_PERCENT_LOSS_EXCEL_PALLETS.dta", replace
