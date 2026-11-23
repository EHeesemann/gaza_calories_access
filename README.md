## Availability, consumption and inequality in access to calories during two years of war and food import restrictions in the Gaza Strip
### Open-access data and STATA code for the main results of the analysis
October 2026

The directory contains two main folders: One for the estimation of calories available on monthly basis from local production and the incoming food and stock piles.

## Repository structure
```
├── Local production/
│   ├── Input data/
│   └── Scripts/
├── Incoming and stock/
│   ├── Input data/
│   └── Scripts/
└── README.md
```

## Local production
This analysis estimates monthly kilocalories (kcal) per person per day available from local crop and livestock production in the Gaza Strip, from October 2023 to September 2025.
 
### Input data
`Local production/Input data` contains `raw_kcal_montly_value.xlsx`, which has three worksheets:
* `Sheet 1` is the dataset read by the script. It has one row per month (September 2023 to September 2025) with the following variables:
  * `aggr_tot_kcal_crop_Gaza` and `aggr_croploss_kcal_Gaza`: aggregate kcal from crop production and crop losses in the Gaza Strip, available for December 2023 and September 2024;
  * `aggr_tot_kcal_live_Gaza` and `aggr_live_loss_kcal_Gaza`: the same for livestock;
  * `Damage cropland from NLS`: share of damaged cropland, available for selected months;
  * `pop_monthly`: monthly population of the Gaza Strip [source to be added].
* `kcal_loss` documents the source of the crop and livestock kcal estimates: Heesemann, E., Macchioni Giaquinto, A., Staffieri, I., Sitko, N.J. & Davis, B. 2026. *The impacts of the Gaza conflict in 2023/24 – Short- and medium-term harm to agriculture, income, and food availability and diversity.* FAO. https://openknowledge.fao.org/handle/20.500.14283/ce1149en
* `Damaged land` documents the sources of the cropland damage shares, which are FAO and UNITAR/UNOSAT satellite assessments:
| Reference date | Damaged cropland | Source |
|---|---|---|
| 1 Dec 2023 | 8% | [FAO 2024](https://openknowledge.fao.org/handle/20.500.14283/cc9279en) |
| 31 Dec 2023 | 28% | [FAO 2024](https://openknowledge.fao.org/handle/20.500.14283/cc9399en) |
| 15 Feb 2024 | 43% | [FAO 2024](https://openknowledge.fao.org/handle/20.500.14283/cc9795en) |
| 20 May 2024 | 57% | [FAO 2024](https://openknowledge.fao.org/handle/20.500.14283/cd1141en) |
| 1 Sep 2024 | 68% | [FAO & UNITAR 2024](https://openknowledge.fao.org/handle/20.500.14283/cd2595en) |
| 31 Dec 2024 | 75% | [FAO, UNITAR & UNOSAT 2025](https://openknowledge.fao.org/handle/20.500.14283/cd4036en) |
| Apr 2025 | 81% | [FAO, UNITAR & UNOSAT 2025](https://openknowledge.fao.org/server/api/core/bitstreams/c4be554e-170f-413e-ae57-f77030be8d09/content) |
| 30 Apr 2025 | 83% | [FAO, UNITAR & UNOSAT 2025](https://openknowledge.fao.org/handle/20.500.14283/cd5507en) |
| 28 Jul 2025 | 86% | [FAO, UNITAR & UNOSAT 2025](https://openknowledge.fao.org/server/api/core/bitstreams/c93215e8-2ac0-4e36-a82b-25ee66fa80b7/content) |
 
### Scripts
`Local production/Scripts` contains `02_imputation_damage_monthly.do`, which:
1. imports `Sheet 1` of `raw_kcal_montly_value.xlsx` and computes the kcal remaining after losses for crops and livestock;
2. linearly interpolates and extrapolates (`ipolate, epolate`) the cropland damage share across months;
3. derives livestock mortality by linear interpolation between 0% (September 2023), 31% (December 2023) and 73% (September 2024), as in the main paper, capped at 100%;
4. applies elasticities of kcal with respect to undamaged cropland (1.46) and surviving livestock (1.84), estimated from log-linear regressions in the script, to the month-on-month change in undamaged cropland and livestock. This yields monthly kcal estimates;
5. divides by the monthly population to obtain kcal per person per day from crops, livestock and both combined;
6. exports the results to `Output data/kcal_left_monthly_oct23_sept25.xls`.
**Note:** before running the script, set the global `root` to the `Local production` folder, e.g. `global root "C:/Users/[name]/[repository]/Local production"`, and create an `Output data` subfolder.

## Incoming and stock
### Input data
The following datasets are included in `Income and stock/Input data`:
* `dataset_1.xlsx`: [short description; source and download date, with link];
* `dataset_2.csv`: [short description; source and download date, with link].

### Scripts
The following do-files in `Income and stock/Scripts` should be run in order:
* `01_prepare_data.do` reads and cleans the input data;
* `02_analysis.do` [main analysis];
* `03_figures_tables.do` produces the figures and tables.
## Replicating the analysis
1. Download and unzip the repository (green **Code** button > **Download ZIP**), or clone it:
   `git clone https://github.com/[username]/[repository].git`
2. Open `00_master.do` and set the path to the repository folder at the top of the file.
3. Run `00_master.do`. Outputs are saved to `/out`.

Tested with Stata on 18.0 on Windows.


