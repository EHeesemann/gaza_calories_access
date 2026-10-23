## Availability, consumption and inequality in access to calories during two years of war and food import restrictions in the Gaza Strip
### Open-access data and STATA code for the main results of the analysis
October 2026

[One or two sentences on what the repository contains, and a link to the paper once published: https://doi.org/xx.xxxx/xxxxx]

## Repository structure
```
├── in/          # input data
├── code/        # analysis scripts
├── out/         # created automatically when the code is run
└── README.md
```

## Input data
The following datasets are included in the `/in` directory:
* `dataset_1.xlsx`: [short description; source and download date, with link];
* `dataset_2.csv`: [short description; source and download date, with link].

[If some data cannot be shared, say so here and explain why, e.g. ethics or licensing restrictions.]

## Scripts
`00_master.do` sets the working directory, installs required packages (e.g. `ssc install estout`) and runs the following scripts in order:
* `01_prepare_data.do` reads and cleans the input data;
* `02_analysis.do` [main analysis; note expected run time if long];
* `03_figures_tables.do` produces all figures and tables in the paper.

## Replicating the analysis
1. Download and unzip the repository (green **Code** button > **Download ZIP**), or clone it:
   `git clone https://github.com/[username]/[repository].git`
2. Open `00_master.do` and set the path to the repository folder at the top of the file.
3. Run `00_master.do`. Outputs are saved to `/out`.

Tested with Stata  on 17.0 on Windows .

## Citation
[Authors]. [Title]. [Journal] [Year]. https://doi.org/xx.xxxx/xxxxx


## Contact
Corresponding author:
