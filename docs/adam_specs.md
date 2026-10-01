# ADaM specifications

Study: CDISCPILOT01 (xanomeline transdermal patch, mild to moderate Alzheimer's disease)
Source: CDISC pilot SDTM from the `pharmaversesdtm` package

These are the derivation rules both the R and SAS programs follow. Anything not listed is copied directly from SDTM.

## ADSL – one record per subject (306 records)

| Variable | Label | Derivation |
|---|---|---|
| TRT01P / TRT01PN | Planned treatment | DM.ARM. Numeric: Placebo = 0, Low Dose = 54, High Dose = 81 |
| TRT01A / TRT01AN | Actual treatment | DM.ACTARM, same coding |
| TRTSDT | First exposure date | Earliest EX.EXSTDTC |
| TRTEDT | Last exposure date | Latest EX.EXENDTC. If EXENDTC is missing on a record, EXSTDTC of that record is used (see data issue 2) |
| TRTDURD | Treatment duration (days) | TRTEDT − TRTSDT + 1 |
| RANDDT | Randomisation date | DS.DSSTDTC where DSDECOD = "RANDOMIZED" |
| EOSDT | End of study date | DS.DSSTDTC where DSCAT = "DISPOSITION EVENT" |
| EOSSTT | End of study status | "COMPLETED" if DSDECOD = "COMPLETED", else "DISCONTINUED" |
| DCSREAS | Discontinuation reason | DS.DSDECOD when not completed |
| DTHDT | Death date | DM.DTHDTC |
| AGEGR1 / AGEGR1N | Age group | <65 (1), 65–80 (2), >80 (3) |
| WEIGHTBL | Baseline weight (kg) | VS.VSSTRESN, VSTESTCD = "WEIGHT" and VSBLFL = "Y" |
| HEIGHTBL | Baseline height (cm) | VS.VSSTRESN, VSTESTCD = "HEIGHT" at VISIT = "SCREENING 1" |
| BMIBL | Baseline BMI | WEIGHTBL / (HEIGHTBL/100)², not rounded |
| ITTFL | ITT flag | "Y" if RANDDT is not missing, else "N" |
| SAFFL | Safety flag | "Y" if TRTSDT is not missing, else "N" |

## ADAE – one record per AE (1191 records)

| Variable | Label | Derivation |
|---|---|---|
| TRTA / TRTAN | Actual treatment | ADSL.TRT01A / TRT01AN |
| ASTDT | Analysis start date | AE.AESTDTC. Partial dates: YYYY-MM → 1st of month; YYYY → 1 Jan. If TRTSDT falls inside the possible range of the partial date and is later than the imputed date, use TRTSDT |
| ASTDTF | Start date imputation flag | "D" if day imputed, "M" if month and day imputed |
| AENDT | Analysis end date | AE.AEENDTC, complete dates only (no imputation) |
| ASTDY / AENDY | Relative day | date − TRTSDT + 1 if on/after TRTSDT, else date − TRTSDT (no day 0) |
| TRTEMFL | Treatment-emergent flag | "Y" if ASTDT ≥ TRTSDT and ASTDT ≤ TRTEDT + 30 |
| AOCCPFL | 1st occurrence of PT | "Y" on the first TEAE per subject / SOC / PT, ordered by ASTDT then AESEQ |

## ADTTE – one record per safety subject, PARAMCD = TTDE (254 records)

| Variable | Derivation |
|---|---|
| PARAM | "Time to First Dermatologic Event (Days)" |
| STARTDT | ADSL.TRTSDT |
| Event | First TEAE (TRTEMFL = "Y") with AEBODSYS = "SKIN AND SUBCUTANEOUS TISSUE DISORDERS" or AEDECOD starting "APPLICATION SITE". Ties on date broken by lowest AESEQ |
| Censoring | No event: censored at min(TRTEDT + 30, EOSDT) |
| ADT | Event date or censoring date |
| CNSR | 0 = event, 1 = censored |
| AVAL | ADT − STARTDT + 1 |
| EVNTDESC / SRCDOM / SRCVAR / SRCSEQ | "DERMATOLOGIC EVENT" / ADAE / ASTDT / AESEQ for events; "LAST FOLLOW-UP" / ADSL / LSTFUDT for censored |

## Data issues found

1. **Planned vs actual treatment.** 12 subjects randomised to Xanomeline High Dose actually received Low Dose (ARM ≠ ACTARM). Safety outputs use actual treatment, so the Low Dose column has 96 subjects rather than 84.
2. **Missing exposure end dates.** 6 subjects have no EXENDTC on their last EX record; 2 of them (01-705-1018, 01-705-1382) have no end date on any record and DM.RFXENDTC is also missing. TRTEDT uses EXSTDTC of that record so these subjects still get a treatment end date.
3. **Partial AE start dates.** 26 AE records have only a year (11) or year-month (15). 20 of them start before first dose (19 by more than a year, e.g. 1977, 1986), so they look like medical history recorded in AE and are not treatment-emergent. The other 6 (subjects 01-701-1239 and 01-716-1418) fall during treatment and are flagged TEAE after imputation to the 1st of the month.
4. **Missing baseline weight.** One safety subject has no baseline weight, so BMIBL is missing (n = 253 for weight and BMI in Table 14.1.1).
