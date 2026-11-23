**************************************************************************
*
* Example: lognormal Monte Carlo distribution of individual daily calories
*          CV = 0.4; 5% loss scenario; 350 replications per month/scenario
*
* Input:  mc_cv_04_5pc.dta (month, scen, pop, mu, cv)
* Output: inequality/5_pc_loss/inequality_<month>_<scen>_04_lognormal.dta
*         inequality/5_pc_loss/master_inequality_5pc.dta
*
* Other CV/loss scenarios: change the input, output directory, and suffix.
* Run from the project root (or set the working directory beforehand).
**************************************************************************

clear all
set more off
set seed 12345

* ---- Settings: edit together when changing the scenario ----
local input_file "mc_cv_04_5pc.dta"
local outdir "inequality/5_pc_loss"
local cv_tag "04"
local loss_tag "5pc"
local mc_runs 350
local bin_width 50

capture mkdir "inequality"
capture mkdir "`outdir'"


capture program drop montec_run
program define montec_run
    syntax, MU(real) CV(real) POP(real) MONTH(string) SCEN(string) ///
        OUTDIR(string) CVTAG(string) RUNS(integer) BINWIDTH(real)

    if (`mu' < 0 | `cv' < 0 | `pop' <= 0 | `runs' < 1 | `binwidth' <= 0) {
        display as error "Invalid mu, cv, pop, runs or binwidth."
        exit 198
    }

    local n = round(`pop')
    if (`n' < 2) {
        display as error "Population must round to at least two persons."
        exit 198
    }

    local sigma_ln = sqrt(ln(1 + `cv'^2))
    local total_kcal = `mu' * `n'

    * Missing bins are treated as zero in the final average:
    * sum(percentages across runs) / total number of runs.
    tempfile sim_results
    tempname handle
    postfile `handle' double bin double pct using `sim_results', replace

    forvalues rep = 1/`runs' {
        clear
        set obs `n'
        generate double weight = exp(rnormal(0, `sigma_ln'))
        quietly summarize weight, meanonly
        generate double kcal = weight / r(sum) * `total_kcal'

        generate double bin = floor(kcal / `binwidth') * `binwidth'
        generate byte one = 1
        collapse (count) freq=one, by(bin)
        generate double pct = 100 * freq / `n'

        quietly {
            forvalues j = 1/`=_N' {
                post `handle' (bin[`j']) (pct[`j'])
            }
        }
    }
    postclose `handle'

    use `sim_results', clear
    collapse (sum) total_pct=pct, by(bin)
    generate double avg_pct = total_pct / `runs'
    drop total_pct
    sort bin

    * The midpoint approximation is for diagnostics only; the simulation
    * itself preserves the exact target mean by normalization.
    generate double kcal_mid = bin + `binwidth'/2
    generate double weighted_kcal = avg_pct * kcal_mid
    quietly summarize weighted_kcal, meanonly
    local approximate_mean = r(sum) / 100
    quietly summarize avg_pct, meanonly
    local sum_pct = r(sum)

    if abs(`sum_pct' - 100) > 0.0001 {
        display as error "Histogram percentages do not sum to 100."
        exit 459
    }

    local outfile "`outdir'/inequality_`month'_`scen'_`cvtag'_lognormal.dta"
    save "`outfile'", replace

    display as result "Finished: `month' / `scen'"
    display as text   "Target mean (kcal/person): " %12.3f `mu'
    display as text   "Histogram midpoint mean:   " %12.3f `approximate_mean'
    display as text   "Target CV:                 " %6.3f `cv'
    display as text   "Sum of histogram shares:   " %9.5f `sum_pct'
end

use "`input_file'", clear
confirm variable month scen pop mu cv
confirm string variable month
confirm string variable scen
confirm numeric variable pop
confirm numeric variable mu
confirm numeric variable cv
assert !missing(month, scen, pop, mu, cv)
assert pop > 0 & mu >= 0 & cv >= 0
assert round(pop) >= 2
assert !strpos(month, "/") & !strpos(month, "\")
assert !strpos(scen, "/") & !strpos(scen, "\")

local n_scenarios = _N
if `n_scenarios' == 0 {
    display as error "Input dataset contains no scenarios."
    exit 2000
}

tempfile scenario_data
save `scenario_data', replace

forvalues i = 1/`n_scenarios' {
    use `scenario_data', clear

    local month = month[`i']
    local scen  = scen[`i']
    local pop   = pop[`i']
    local mu    = mu[`i']
    local cv    = cv[`i']

    montec_run, mu(`mu') cv(`cv') pop(`pop') ///
        month("`month'") scen("`scen'") outdir("`outdir'") ///
        cvtag("`cv_tag'") runs(`mc_runs') binwidth(`bin_width')
}

/**************************************************************************
*Aggregate outputs from  CV/loss scenario.
**************************************************************************/
local files : dir "`outdir'" files "inequality_*_`cv_tag'_lognormal.dta"
if `"`files'"' == "" {
    display as error "No simulation outputs found in `outdir'."
    exit 601
}

tempfile master
local first = 1
foreach f of local files {
    display as text "Aggregating: `f'"
    use "`outdir'/`f'", clear

    local base = subinstr("`f'", "inequality_", "", 1)
    local base = subinstr("`base'", "_`cv_tag'_lognormal.dta", "", 1)
    local pos = strpos("`base'", "_")
    if `pos' == 0 {
        display as error "Unexpected filename format: `f'"
        exit 459
    }
    local month = substr("`base'", 1, `pos' - 1)
    local scen  = substr("`base'", `pos' + 1, .)

    generate str60 month = "`month'"
    generate str60 scen = "`scen'"
    generate double cv = real("0.`cv_tag'")
    generate str10 loss = "`loss_tag'"

    if `first' {
        save `master', replace
        local first = 0
    }
    else {
        append using `master'
        save `master', replace
    }
}

use `master', clear
sort month scen bin
order month scen cv loss bin avg_pct kcal_mid weighted_kcal
save "`outdir'/master_inequality_`loss_tag'.dta", replace

bysort month scen: egen double check_pct = total(avg_pct)
assert abs(check_pct - 100) < 0.0001
drop check_pct

