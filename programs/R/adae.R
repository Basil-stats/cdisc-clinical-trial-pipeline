#-------------------------------------------------------------------------------
# Program  : adae.R
# Purpose  : Create ADAE (adverse events analysis dataset)
# Input    : data/sdtm/ae.xpt, data/adam/adsl.rds
# Output   : data/adam/adae.rds, data/adam/adae.xpt
# Spec     : docs/adam_specs.md
# Author   : Basil E
#-------------------------------------------------------------------------------

library(admiral)
library(dplyr)
library(haven)

source("programs/R/utils.R")

ae   <- read_xpt("data/sdtm/ae.xpt") %>% convert_blanks_to_na()
adsl <- readRDS("data/adam/adsl.rds")

adae <- ae %>%
  select(STUDYID, USUBJID, AESEQ, AETERM, AEDECOD, AEBODSYS, AESEV, AESER,
         AEREL, AESTDTC, AEENDTC) %>%
  derive_vars_merged(
    dataset_add = adsl,
    by_vars     = exprs(STUDYID, USUBJID),
    new_vars    = exprs(TRTSDT, TRTEDT, TRTA = TRT01A, TRTAN = TRT01AN, SAFFL)
  )

# AE start date - 26 records only have year or year-month.
# Impute to the first day of the month / year, but not earlier than the first
# dose if the first dose falls in that month / year.
adae <- adae %>%
  derive_vars_dt(
    dtc                = AESTDTC,
    new_vars_prefix    = "AST",
    highest_imputation = "M",
    date_imputation    = "first",
    min_dates          = exprs(TRTSDT)
  ) %>%
  derive_vars_dt(dtc = AEENDTC, new_vars_prefix = "AEN") %>%
  derive_vars_dy(reference_date = TRTSDT, source_vars = exprs(ASTDT, AENDT))

# treatment-emergent: started on/after first dose and up to 30 days after last dose
adae <- adae %>%
  mutate(
    TRTEMFL = if_else(
      !is.na(TRTSDT) & ASTDT >= TRTSDT & (is.na(TRTEDT) | ASTDT <= TRTEDT + 30),
      "Y", NA_character_
    )
  )

# first occurrence of each preferred term per subject (TEAEs only)
adae <- adae %>%
  restrict_derivation(
    derivation = derive_var_extreme_flag,
    args = params(
      by_vars = exprs(USUBJID, AEBODSYS, AEDECOD),
      order   = exprs(ASTDT, AESEQ),
      new_var = AOCCPFL,
      mode    = "first"
    ),
    filter = TRTEMFL == "Y"
  )

# restrict_derivation() drops variable labels - copy them back from AE and ADSL
for (v in intersect(names(adae), names(ae)))   attr(adae[[v]], "label") <- attr(ae[[v]], "label")
for (v in c("TRTSDT", "TRTEDT", "SAFFL"))      attr(adae[[v]], "label") <- attr(adsl[[v]], "label")

adae <- adae %>%
  select(STUDYID, USUBJID, AESEQ, AETERM, AEDECOD, AEBODSYS, AESEV, AESER,
         AEREL, AESTDTC, AEENDTC, ASTDT, ASTDTF, AENDT, ASTDY, AENDY,
         TRTSDT, TRTEDT, TRTA, TRTAN, SAFFL, TRTEMFL, AOCCPFL) %>%
  arrange(USUBJID, AESEQ)

adae <- add_labels(adae, c(
  ASTDT = "Analysis Start Date", ASTDTF = "Analysis Start Date Imputation Flag",
  AENDT = "Analysis End Date", ASTDY = "Analysis Start Relative Day",
  AENDY = "Analysis End Relative Day", TRTA = "Actual Treatment",
  TRTAN = "Actual Treatment (N)", TRTEMFL = "Treatment Emergent Analysis Flag",
  AOCCPFL = "1st Occurrence within PT Flag"
))

# checks
count(adae, ASTDTF)
count(adae, TRTEMFL)
filter(adae, !is.na(ASTDTF)) %>% select(USUBJID, AESTDTC, TRTSDT, ASTDT, ASTDTF) %>% print(n = 30)

saveRDS(adae, "data/adam/adae.rds")
write_xpt(adae, "data/adam/adae.xpt", version = 5, name = "ADAE",
          label = "Adverse Events Analysis Dataset")
