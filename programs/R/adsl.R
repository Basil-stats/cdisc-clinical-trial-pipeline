#-------------------------------------------------------------------------------
# Program  : adsl.R
# Purpose  : Create ADSL (subject-level analysis dataset)
# Study    : CDISC pilot - xanomeline in mild to moderate Alzheimer's disease
# Input    : data/sdtm/ dm, ex, ds, vs
# Output   : data/adam/adsl.rds, data/adam/adsl.xpt
# Spec     : docs/adam_specs.md
# Author   : Basil E
#-------------------------------------------------------------------------------

library(admiral)
library(dplyr)
library(haven)

source("programs/R/utils.R")

dm <- read_xpt("data/sdtm/dm.xpt") %>% convert_blanks_to_na()
ex <- read_xpt("data/sdtm/ex.xpt") %>% convert_blanks_to_na()
ds <- read_xpt("data/sdtm/ds.xpt") %>% convert_blanks_to_na()
vs <- read_xpt("data/sdtm/vs.xpt") %>% convert_blanks_to_na()

# treatment variables -----------------------------------------------------------
dose_n <- c("Placebo" = 0, "Xanomeline Low Dose" = 54, "Xanomeline High Dose" = 81)

adsl <- dm %>%
  select(STUDYID, USUBJID, SUBJID, SITEID, AGE, AGEU, SEX, RACE, ETHNIC,
         COUNTRY, ARM, ACTARM, DTHFL, DTHDTC) %>%
  mutate(
    TRT01P  = ARM,
    TRT01PN = unname(dose_n[ARM]),
    TRT01A  = ACTARM,
    TRT01AN = unname(dose_n[ACTARM])
  )

# first / last exposure dates
# 6 subjects have no EXENDTC on their last EX record. In those cases the start
# date of that record is used - the subject still took at least one dose that day.
ex_dt <- ex %>%
  derive_vars_dt(dtc = EXSTDTC, new_vars_prefix = "EXST") %>%
  derive_vars_dt(dtc = EXENDTC, new_vars_prefix = "EXEN") %>%
  mutate(EXENDT = coalesce(EXENDT, EXSTDT))

adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ex_dt,
    by_vars     = exprs(STUDYID, USUBJID),
    filter_add  = !is.na(EXSTDT),
    new_vars    = exprs(TRTSDT = EXSTDT),
    order       = exprs(EXSTDT, EXSEQ),
    mode        = "first"
  ) %>%
  derive_vars_merged(
    dataset_add = ex_dt,
    by_vars     = exprs(STUDYID, USUBJID),
    filter_add  = !is.na(EXENDT),
    new_vars    = exprs(TRTEDT = EXENDT),
    order       = exprs(EXENDT, EXSEQ),
    mode        = "last"
  ) %>%
  derive_var_trtdurd()

# randomisation and disposition ---------------------------------------------------
ds_dt <- derive_vars_dt(ds, dtc = DSSTDTC, new_vars_prefix = "DSST")

adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ds_dt,
    by_vars     = exprs(STUDYID, USUBJID),
    filter_add  = DSDECOD == "RANDOMIZED",
    new_vars    = exprs(RANDDT = DSSTDT)
  ) %>%
  derive_vars_merged(
    dataset_add = ds_dt,
    by_vars     = exprs(STUDYID, USUBJID),
    filter_add  = DSCAT == "DISPOSITION EVENT",
    new_vars    = exprs(
      EOSDT   = DSSTDT,
      EOSSTT  = if_else(DSDECOD == "COMPLETED", "COMPLETED", "DISCONTINUED"),
      DCSREAS = if_else(DSDECOD == "COMPLETED", NA_character_, DSDECOD)
    )
  ) %>%
  derive_vars_dt(dtc = DTHDTC, new_vars_prefix = "DTH")

# baseline height / weight / BMI ---------------------------------------------------
adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = vs,
    by_vars     = exprs(STUDYID, USUBJID),
    filter_add  = VSTESTCD == "WEIGHT" & VSBLFL == "Y",
    new_vars    = exprs(WEIGHTBL = VSSTRESN)
  ) %>%
  derive_vars_merged(
    dataset_add = vs,
    by_vars     = exprs(STUDYID, USUBJID),
    filter_add  = VSTESTCD == "HEIGHT" & VISIT == "SCREENING 1",
    new_vars    = exprs(HEIGHTBL = VSSTRESN)
  ) %>%
  mutate(BMIBL = WEIGHTBL / (HEIGHTBL / 100)^2)

# age group and population flags ------------------------------------------------------
adsl <- adsl %>%
  mutate(
    AGEGR1 = case_when(
      AGE < 65  ~ "<65",
      AGE <= 80 ~ "65-80",
      AGE > 80  ~ ">80"
    ),
    AGEGR1N = case_when(AGEGR1 == "<65" ~ 1, AGEGR1 == "65-80" ~ 2, AGEGR1 == ">80" ~ 3),
    ITTFL   = if_else(!is.na(RANDDT), "Y", "N"),
    SAFFL   = if_else(!is.na(TRTSDT), "Y", "N")
  )

adsl <- adsl %>%
  select(STUDYID, USUBJID, SUBJID, SITEID, AGE, AGEU, AGEGR1, AGEGR1N, SEX,
         RACE, ETHNIC, COUNTRY, ARM, ACTARM, TRT01P, TRT01PN, TRT01A, TRT01AN,
         RANDDT, TRTSDT, TRTEDT, TRTDURD, EOSDT, EOSSTT, DCSREAS, DTHFL, DTHDT,
         HEIGHTBL, WEIGHTBL, BMIBL, ITTFL, SAFFL) %>%
  arrange(USUBJID)

adsl_labels <- c(
  AGEGR1 = "Pooled Age Group 1", AGEGR1N = "Pooled Age Group 1 (N)",
  TRT01P = "Planned Treatment for Period 01", TRT01PN = "Planned Treatment for Period 01 (N)",
  TRT01A = "Actual Treatment for Period 01", TRT01AN = "Actual Treatment for Period 01 (N)",
  RANDDT = "Date of Randomization", TRTSDT = "Date of First Exposure to Treatment",
  TRTEDT = "Date of Last Exposure to Treatment", TRTDURD = "Total Treatment Duration (Days)",
  EOSDT = "End of Study Date", EOSSTT = "End of Study Status",
  DCSREAS = "Reason for Discontinuation from Study", DTHDT = "Date of Death",
  HEIGHTBL = "Baseline Height (cm)", WEIGHTBL = "Baseline Weight (kg)",
  BMIBL = "Baseline BMI (kg/m2)", ITTFL = "Intent-To-Treat Population Flag",
  SAFFL = "Safety Population Flag"
)
adsl <- add_labels(adsl, adsl_labels)

# checks
count(adsl, TRT01P, TRT01A)
count(adsl, ITTFL, SAFFL)
count(adsl, EOSSTT, DCSREAS)

saveRDS(adsl, "data/adam/adsl.rds")
write_xpt(adsl, "data/adam/adsl.xpt", version = 5, name = "ADSL",
          label = "Subject-Level Analysis Dataset")
