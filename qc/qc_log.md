# QC log

Independent double programming: each ADaM dataset is programmed separately in R and SAS from the same SDTM inputs and compared with PROC COMPARE (`programs/SAS/qc_compare.sas`) and diffdf (`programs/R/qc_compare.R`).

Pass criterion: no unequal values (numeric tolerance 1e-8). Differences in variable length, label or format are noted but are not value differences.

| Dataset | R program | SAS program | Compared on | Result | Notes |
|---|---|---|---|---|---|
| ADSL | adsl.R | adsl.sas | | | |
| ADAE | adae.R | adae.sas | | | |
| ADTTE | adtte.R | adtte.sas | | | |

## Discrepancies and resolutions

| Date | Dataset | Variable | Issue | Resolution |
|---|---|---|---|---|
| | | | | |
