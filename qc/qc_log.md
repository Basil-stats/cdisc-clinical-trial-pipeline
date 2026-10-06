# QC log

Independent double programming: each ADaM dataset is programmed separately in R and SAS from the same SDTM inputs and compared with PROC COMPARE (`programs/SAS/qc_compare.sas`) and diffdf (`programs/R/qc_compare.R`).

Pass criterion: no unequal values (numeric tolerance 1e-8). Differences in variable length, label or format are noted but are not value differences.

| Dataset | R program | SAS program | Compared on | Result | Notes |
|---|---|---|---|---|---|
| ADSL | adsl.R | adsl.sas | 2026-10-06 | Pass – no unequal values (306 obs, 32 vars) | Attribute-only differences: DATE9. vs DATE. formats on 6 date variables; character lengths of TRT01P, TRT01A, DCSREAS ($40 in SAS vs actual length in R) |
   | ADAE | adae.R | adae.sas | 2026-10-06 | Pass – no unequal values (1191 obs, 23 vars) | Attribute-only differences remaining: DATE9. vs DATE. formats; TRTA length |
| ADTTE | adtte.R | adtte.sas | 2026-10-06 | Pass – no unequal values (254 obs, 15 vars) | Attribute-only differences: date formats, character lengths |

## Discrepancies and resolutions
|---|---|---|---|---|
| 2026-10-06 | ADAE | SDTM-derived variables (STUDYID, AETERM, AEBODSYS, …) | Variable labels missing in R output; PROC COMPARE showed label differences vs SAS | admiral restrict_derivation() drops labels; labels re-attached from AE/ADSL after that step in adae.R |
| 2026-10-06 | ADTTE | STUDYID, USUBJID | Labels missing in R output | derive_param_tte() creates these without labels; added to add_labels() in adtte.R |
   | 2026-10-06 | T-DEMOG, T-AE | Percentages | 6/96 = 6.25%: SAS 6.3, R 6.2 (R rounds halves to even) | Added round_half_up() in utils.R; R now matches SAS |
   | 2026-10-06 | T-AE | SOC label | Longest SOC name truncated in R text table | Widened first column to 72 characters |
   | 2026-10-06 | F-KM | Cox HR | SAS 4.018/5.132 vs R 4.048/5.179 | Tie handling differs (SAS Breslow vs R Efron); SAS set to ties=efron |
   
| Date | Dataset | Variable | Issue | Resolution |
|---|---|---|---|---|
| | | | | |
