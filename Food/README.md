├── Local production/

│   ├── Input data/

│   │   └── raw\_kcal\_montly\_value.xlsx

│   ├── Scripts/

│   │   └── 02\_imputation\_damage\_monthly.do

│   └── Output data/

│       └── kcal\_left\_monthly\_oct23\_sept25.xls

│

├── Food/

│   ├── Input Data/

│   │   ├── DTA FOR CALORIC CONVERSION/

│   │   ├── COGAT\_DATA\_OCT\_2023\_SEPTEMBER\_2025.xlsx

│   │   ├── UN\_Platform\_Commodities Received.xlsx

│   │   └── UN\_PLATFORM\_FOOD\_ITEM\_LIST.xlsx

│   │

│   └── Script/

│       ├── 01\_UN\_Platform\_Caloric\_Conversion.do

│       ├── 02\_UN\_Platform\_Donor\_Conversion\_Factors.do

│       ├── 03\_COGAT\_Caloric\_Conversion.do

│       ├── 04\_UN\_Pallets\_Monthly\_Availability.do

│       ├── 05\_UN\_20MT\_Monthly\_Availability.do

│       ├── 06\_COGAT\_Monthly\_Availability\_excel.do

│       ├── 07\_UN\_Pallets\_Monthly\_Consumption\_21\_oct\_2023\_31\_dec\_2024.do

│       ├── 08\_UN\_20MT\_Monthly\_Consumption\_21\_oct\_2023\_31\_dec\_2024.do

│       ├── 09\_COGAT\_Monthly\_Consumption\_21\_oct\_2023\_31\_dec\_2024.do

│       ├── 10\_Monthly\_Consumption\_01\_jan\_30\_sep\_2025.do

│       ├── 11\_Inequality\_Scenarios\_Setup.do

│       └── 12\_Inequality\_Simulations.do

│

└── 



**2. Food imports, caloric availability and consumption**

This component estimates caloric availability and modelled caloric consumption using food shipment records, pre-war food stock estimates, local production and monthly population data.

The analysis covers 21 October 2023 to 30 September 2025.

**2.1 Input data**

The Food/Input Data/ folder contains the datasets used for caloric conversion and the subsequent availability and consumption calculations.

**Food shipment data**

Food shipment and truck-entry data can be downloaded directly from the original UN Platform and COGAT sources. Alternatively, two Excel files are provided in the repository, allowing users to work directly with the datasets used in the analysis:

* UN\_Platform\_Commodities Received.xlsx: UN Platform food shipment records used to estimate caloric inflows for October 2023–December 2024.
* COGAT\_DATA\_OCT\_2023\_SEPTEMBER\_2025.xlsx: archived COGAT analytical workbook covering October 2023–September 2025. The COGAT DATA worksheet is used in the subsequent calculations.

Original data sources:

1. [https://gaza-aid-data.gov.il/mainhome](https://gaza-aid-data.gov.il/mainhome)
2. [UN platform](https://app.powerbi.com/view?r=eyJrIjoiZTVkYmEwNmMtZWYxNy00ODhlLWI2ZjctNjIzMzQ5OGQxNzY5IiwidCI6IjI2MmY2YTQxLTIwZTktNDE0MC04ZDNlLWZkZjVlZWNiNDE1NyIsImMiOjl9&pageName=ReportSection3306863add46319dc574)

**Please note:** Historical shipment records may be subject to retrospective revisions and adjustments, including corrections to reported quantities, classifications and individual shipments. Consequently, data downloaded at a later date may differ from those used in the analysis, even when covering the same reporting period.

For this reason, we recommend using the archived Excel files provided in the repository to reproduce the published results. Newly downloaded data can be used to update the analysis or assess differences arising from subsequent revisions.

**Additional input data**

The repository also includes

* UN\_PLATFORM\_FOOD\_ITEM\_LIST.xlsx: list of food commodities used to support the classification and caloric conversion of food shipments.
* DTA FOR CALORIC CONVERSION/: supporting Stata datasets, including calories\_tok1.dta

Other analytical inputs include monthly population estimates (retrievable from the SI), monthly calories from local crop and livestock production, pre-war food stock estimates, and assumptions regarding food losses and stockpile carryover.

**Pre-war food stocks**

Historical pre-war food stock estimates were derived from disaggregated data shared with the authors through personal communication. The original data cannot be redistributed. However, the population-level food stock estimates calculated from these data and used in the analysis are provided in stock\_pre\_war.xlsx (worksheet stock pre war) to support reproducibility.

**Gaza Humanitarian Foundation (GHF) data**

GHF-related calculations were based on daily updates published on the Gaza Humanitarian Foundation website during the study period. These data are not included in the repository, and the original webpage is no longer accessible. As a result, the GHF-related calculations cannot be independently reproduced using the materials provided in this repository.

**2.2 Stata scripts**

The Food/Script/ folder contains 12 Stata do-files covering the main stages of the analysis, from caloric conversion of incoming food shipments to the estimation of caloric availability, consumption and inequality. The Local production analysis must be completed first, as its monthly estimates are required for the subsequent calculations. The Food scripts should then be run in numerical order, as some generate intermediate datasets used by later scripts.



**### Step 1: Caloric conversion of incoming food**



| Script | Purpose |

|---|---|

| `01\_UN\_Platform\_Caloric\_Conversion.do` | Converts UN Platform food shipment records into calories under pallets-based and 20-tonne assumptions. |

| `02\_UN\_Platform\_Donor\_Conversion\_Factors.do` | Calculates donor-specific caloric conversion factors using UN Platform donor-level information. |

| `03\_COGAT\_Caloric\_Conversion.do` | Converts COGAT food shipment records into caloric inflows. |



**### Step 2: Monthly caloric availability**



| Script | Purpose |

|---|---|

| `04\_UN\_Pallets\_Monthly\_Availability.do` | Estimates monthly caloric availability using UN Platform pallets-based inflows. |

| `05\_UN\_20MT\_Monthly\_Availability.do` | Estimates monthly caloric availability using the UN Platform 20-tonne assumption. |

| `06\_COGAT\_Monthly\_Availability\_excel.do` | Estimates monthly caloric availability using the archived COGAT workbook. |



**### Step 3: Caloric consumption and stockpile carryover**



| Script | Purpose |

|---|---|

| `07\_UN\_Pallets\_Monthly\_Consumption\_21\_oct\_2023\_31\_dec\_2024.do` | Models monthly caloric consumption for October 2023–December 2024 using UN Platform pallets-based estimates. |

| `08\_UN\_20MT\_Monthly\_Consumption\_21\_oct\_2023\_31\_dec\_2024.do` | Models monthly caloric consumption for the same period using the UN Platform 20-tonne assumption. |

| `09\_COGAT\_Monthly\_Consumption\_21\_oct\_2023\_31\_dec\_2024.do` | Models monthly caloric consumption for October 2023–December 2024 using COGAT data. |

| `10\_Monthly\_Consumption\_01\_jan\_30\_sep\_2025.do` | Estimates monthly caloric consumption and stockpile carryover for January–September 2025. |



**### Step 4: Inequality in access to food**



| Script | Purpose |

|---|---|

| `11\_Inequality\_Scenarios\_Setup.do` | Prepares monthly population and caloric consumption inputs and defines alternative inequality scenarios. |

| `12\_Inequality\_Simulations.do` | Implements Monte Carlo simulations of individual caloric consumption and aggregates the resulting distributions. |



**Running the analysis**

Before running the scripts, users should update the file paths to match their local directory structure. The scripts should be executed in the order indicated above, starting with the Local production component. Intermediate datasets generated by earlier scripts are used in subsequent calculations.

For the closest reproduction of the published estimates, users should rely on the archived input files provided in the repository, as the original data sources may have been revised. The limitations concerning the availability of the original pre-war stock data and GHF daily reports are described in Section 2.1.

