# CDISC Clinical Trial Pipeline: SDTM → ADaM → TFLs

End-to-end statistical programming for a Phase II clinical trial (CDISC Pilot study of xanomeline in Alzheimer's disease), independently double-programmed in **SAS** and **R**.

## Objective
Derive analysis-ready ADaM datasets from SDTM data and produce standard tables, figures and listings (TFLs), with independent QC comparison between SAS and R outputs.

## Data
Public CDISC pilot SDTM data from the [pharmaversesdtm](https://pharmaverse.github.io/pharmaversesdtm/) R package.

## Workflow
| Step | Dataset / Output | R | SAS | QC status |
|---|---|---|---|---|
| 1 | ADSL – subject-level analysis dataset | ✅ | ⏳ | ⏳ |
| 2 | ADAE – adverse events | ⏳ | ⏳ | ⏳ |
| 3 | ADTTE – time to first dermatologic event | ⏳ | ⏳ | ⏳ |
| 4 | Table: demographics by treatment | ⏳ | ⏳ | ⏳ |
| 5 | Table: adverse events by SOC/PT | ⏳ | ⏳ | ⏳ |
| 6 | Figure: Kaplan–Meier curve | ⏳ | ⏳ | ⏳ |

## Repository structure
data/sdtm/ input SDTM datasets
data/adam/ derived ADaM datasets (.rds, .xpt)
programs/R/ R programs (admiral, Tplyr, ggsurvfit)
programs/SAS/ independent SAS programs
qc/ SAS vs R comparison reports
output/ tables and figures
docs/ dataset specifications

## Quality control
Each ADaM dataset is programmed independently in R and SAS and compared variable by variable (PROC COMPARE / diffdf). Discrepancies and resolutions are logged in `qc/`.

## Tools
R (admiral, pharmaversesdtm, dplyr, Tplyr, ggsurvfit, haven) · SAS (DATA step, PROC SQL, PROC COMPARE, PROC REPORT, PROC LIFETEST)

## Author
Basil E · [LinkedIn](https://www.linkedin.com/in/basil-e-biostat) · [GitHub](https://github.com/Basil-stats)
