#-------------------------------------------------------------------------------
# Program  : adtte.R
# Purpose  : Create ADTTE - time to first dermatologic event (PARAMCD = TTDE)
# Input    : data/adam/adsl.rds, data/adam/adae.rds
# Output   : data/adam/adtte.rds, data/adam/adtte.xpt
# Spec     : docs/adam_specs.md
# Author   : Basil E
#-------------------------------------------------------------------------------

library(admiral)
library(dplyr)
library(stringr)
library(haven)

source("programs/R/utils.R")

adsl <- readRDS("data/adam/adsl.rds")
adae <- readRDS("data/adam/adae.rds")

# subjects without an event are censored at last dose + 30 days,
# or at end of study if that is earlier
adsl_fu <- adsl %>%
  mutate(LSTFUDT = pmin(TRTEDT + 30, EOSDT, na.rm = TRUE))

derm_event <- event_source(
  dataset_name = "adae",
  filter = TRTEMFL == "Y" &
    (AEBODSYS == "SKIN AND SUBCUTANEOUS TISSUE DISORDERS" |
       str_detect(AEDECOD, "^APPLICATION SITE")),
  date  = ASTDT,
  order = exprs(AESEQ),
  set_values_to = exprs(
    EVNTDESC = "DERMATOLOGIC EVENT",
    SRCDOM   = "ADAE",
    SRCVAR   = "ASTDT",
    SRCSEQ   = AESEQ
  )
)

last_fu <- censor_source(
  dataset_name = "adsl",
  date   = LSTFUDT,
  censor = 1,
  set_values_to = exprs(
    EVNTDESC = "LAST FOLLOW-UP",
    SRCDOM   = "ADSL",
    SRCVAR   = "LSTFUDT"
  )
)

adtte <- derive_param_tte(
  dataset_adsl      = filter(adsl_fu, SAFFL == "Y"),
  source_datasets   = list(adsl = adsl_fu, adae = adae),
  start_date        = TRTSDT,
  event_conditions  = list(derm_event),
  censor_conditions = list(last_fu),
  set_values_to     = exprs(
    PARAMCD = "TTDE",
    PARAM   = "Time to First Dermatologic Event (Days)"
  )
) %>%
  derive_vars_duration(new_var = AVAL, start_date = STARTDT, end_date = ADT) %>%
  derive_vars_merged(
    dataset_add = adsl,
    by_vars     = exprs(STUDYID, USUBJID),
    new_vars    = exprs(TRTA = TRT01A, TRTAN = TRT01AN, SAFFL)
  )

adtte <- adtte %>%
  select(STUDYID, USUBJID, PARAMCD, PARAM, AVAL, CNSR, STARTDT, ADT,
         EVNTDESC, SRCDOM, SRCVAR, SRCSEQ, TRTA, TRTAN, SAFFL) %>%
  arrange(USUBJID, PARAMCD)

adtte <- add_labels(adtte, c(
  STUDYID = "Study Identifier", USUBJID = "Unique Subject Identifier",
  PARAMCD = "Parameter Code", PARAM = "Parameter", AVAL = "Analysis Value",
  CNSR = "Censor", STARTDT = "Time to Event Origin Date for Subject",
  ADT = "Analysis Date", EVNTDESC = "Event or Censoring Description",
  SRCDOM = "Source Data", SRCVAR = "Source Variable", SRCSEQ = "Source Sequence Number",
  TRTA = "Actual Treatment", TRTAN = "Actual Treatment (N)"
))

# checks
count(adtte, TRTA, CNSR)
summary(adtte$AVAL)

saveRDS(adtte, "data/adam/adtte.rds")
write_xpt(adtte, "data/adam/adtte.xpt", version = 5, name = "ADTTE",
          label = "Time to Event Analysis Dataset")
