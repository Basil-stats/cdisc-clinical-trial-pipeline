#-------------------------------------------------------------------------------
# Program  : full_pipeline.R
# Purpose  : Whole R workflow in one script, in the order it is run:
#            SDTM -> ADSL -> ADAE -> ADTTE -> demog table -> AE table -> KM plot
#            with data checks along the way. The separate programs in
#            programs/R/ do the same thing split into one file per output.
# Study    : CDISC pilot (CDISCPILOT01) - xanomeline in Alzheimer's disease
# Author   : Basil E
# Note     : open cdisc-clinical-trial-pipeline.Rproj first, then run
#            section by section (Ctrl+Enter) to see each step
#-------------------------------------------------------------------------------


# 0. Packages ------------------------------------------------------------------

# install.packages(c("admiral", "pharmaversesdtm", "dplyr", "tidyr", "stringr",
#                    "haven", "survival", "ggplot2", "patchwork", "scales", "diffdf"))

library(admiral)
library(pharmaversesdtm)
library(dplyr)
library(tidyr)
library(stringr)
library(rlang)
library(haven)
library(survival)
library(ggplot2)
library(patchwork)

source("programs/R/utils.R")   # add_labels(), n_pct(), write_txt_table()

getwd()   # should end in /cdisc-clinical-trial-pipeline


# 1. SDTM data -----------------------------------------------------------------

# write the pilot SDTM to .xpt so R and SAS start from the same files
for (d in c("dm", "ex", "ds", "ae", "vs")) {
  df <- get(d, envir = asNamespace("pharmaversesdtm"))
  write_xpt(df, file.path("data/sdtm", paste0(d, ".xpt")),
            version = 5, name = toupper(d))
}
list.files("data/sdtm")

dm <- read_xpt("data/sdtm/dm.xpt") %>% convert_blanks_to_na()
ex <- read_xpt("data/sdtm/ex.xpt") %>% convert_blanks_to_na()
ds <- read_xpt("data/sdtm/ds.xpt") %>% convert_blanks_to_na()
ae <- read_xpt("data/sdtm/ae.xpt") %>% convert_blanks_to_na()
vs <- read_xpt("data/sdtm/vs.xpt") %>% convert_blanks_to_na()

# quick look at each domain
sapply(list(dm = dm, ex = ex, ds = ds, ae = ae, vs = vs), dim)

## DM - one row per subject?
glimpse(dm)
head(dm)
n_distinct(dm$USUBJID) == nrow(dm)
table(dm$ARM, useNA = "ifany")
table(dm$ARM, dm$ACTARM)          # 12 planned High Dose got Low Dose
summary(dm$AGE)
table(dm$SEX)
table(dm$RACE)
colSums(is.na(dm))

## EX - exposure records
str(ex)
head(ex, 10)
count(ex, EXTRT, EXDOSE)
sum(is.na(ex$EXENDTC))            # missing end dates - deal with these in ADSL
ex %>% filter(is.na(EXENDTC)) %>% select(USUBJID, EXSEQ, EXSTDTC, EXENDTC, VISIT)

## DS - disposition
count(ds, DSCAT, DSDECOD)
ds %>% filter(DSCAT == "DISPOSITION EVENT") %>% count(USUBJID) %>% count(n)   # 1 per subject

## VS - only need baseline height and weight
unique(vs$VSTESTCD)
vs %>%
  filter(VSTESTCD %in% c("HEIGHT", "WEIGHT")) %>%
  count(VSTESTCD, VISIT, VSBLFL)

## AE
glimpse(ae)
table(nchar(ae$AESTDTC))          # 4 = year only, 7 = year-month -> partial dates
ae %>% filter(nchar(AESTDTC) < 10) %>% select(USUBJID, AESTDTC, AEDECOD)
count(ae, AEBODSYS, sort = TRUE)
table(ae$AESEV)
table(ae$AESER)


# 2. ADSL ----------------------------------------------------------------------

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

count(adsl, TRT01P, TRT01PN)

## treatment start / end dates
# missing EXENDTC on the last record -> use EXSTDTC of that record
ex_dt <- ex %>%
  derive_vars_dt(dtc = EXSTDTC, new_vars_prefix = "EXST") %>%
  derive_vars_dt(dtc = EXENDTC, new_vars_prefix = "EXEN") %>%
  mutate(EXENDT = coalesce(EXENDT, EXSTDT))

ex_dt %>% select(USUBJID, EXSEQ, EXSTDTC, EXSTDT, EXENDTC, EXENDT) %>% head()

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

# screen failures should be the only ones without TRTSDT
table(adsl$ARM, is.na(adsl$TRTSDT))
summary(adsl$TRTDURD)

## randomisation and end of study
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

count(adsl, EOSSTT, DCSREAS)
adsl %>% filter(!is.na(DTHDT)) %>% select(USUBJID, TRT01A, DTHDT, DCSREAS)

## baseline height, weight, BMI
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

summary(adsl[, c("WEIGHTBL", "HEIGHTBL", "BMIBL")])
hist(adsl$BMIBL, main = "Baseline BMI", xlab = "kg/m2")

## age group and population flags
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

# check the age cut-offs at the boundaries
adsl %>% group_by(AGEGR1) %>% summarise(min = min(AGE), max = max(AGE), n = n())
count(adsl, ITTFL, SAFFL)

## keep, order, label, save
adsl <- adsl %>%
  select(STUDYID, USUBJID, SUBJID, SITEID, AGE, AGEU, AGEGR1, AGEGR1N, SEX,
         RACE, ETHNIC, COUNTRY, ARM, ACTARM, TRT01P, TRT01PN, TRT01A, TRT01AN,
         RANDDT, TRTSDT, TRTEDT, TRTDURD, EOSDT, EOSSTT, DCSREAS, DTHFL, DTHDT,
         HEIGHTBL, WEIGHTBL, BMIBL, ITTFL, SAFFL) %>%
  arrange(USUBJID)

adsl <- add_labels(adsl, c(
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
))

dim(adsl)                         # 306 x 32
n_distinct(adsl$USUBJID)
str(adsl)

saveRDS(adsl, "data/adam/adsl.rds")
write_xpt(adsl, "data/adam/adsl.xpt", version = 5, name = "ADSL",
          label = "Subject-Level Analysis Dataset")


# 3. ADAE ----------------------------------------------------------------------

adae <- ae %>%
  select(STUDYID, USUBJID, AESEQ, AETERM, AEDECOD, AEBODSYS, AESEV, AESER,
         AEREL, AESTDTC, AEENDTC) %>%
  derive_vars_merged(
    dataset_add = adsl,
    by_vars     = exprs(STUDYID, USUBJID),
    new_vars    = exprs(TRTSDT, TRTEDT, TRTA = TRT01A, TRTAN = TRT01AN, SAFFL)
  )

nrow(adae) == nrow(ae)            # merge should not add rows

## start date with imputation for partial dates
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

# look at what got imputed
count(adae, ASTDTF)
adae %>%
  filter(!is.na(ASTDTF)) %>%
  select(USUBJID, AESTDTC, TRTSDT, ASTDT, ASTDTF)

# any day 0? should be none
sum(adae$ASTDY == 0, na.rm = TRUE)

## treatment-emergent flag: first dose to last dose + 30 days
adae <- adae %>%
  mutate(
    TRTEMFL = if_else(
      !is.na(TRTSDT) & ASTDT >= TRTSDT & (is.na(TRTEDT) | ASTDT <= TRTEDT + 30),
      "Y", NA_character_
    )
  )

count(adae, TRTEMFL)
# the non-TEAEs - mostly before first dose
adae %>%
  filter(is.na(TRTEMFL)) %>%
  mutate(when = if_else(ASTDT < TRTSDT, "before 1st dose", "after last dose + 30")) %>%
  count(when)

## first occurrence of each PT per subject
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

# AOCCPFL count should equal the number of distinct subject/PT pairs among TEAEs
sum(adae$AOCCPFL == "Y", na.rm = TRUE)
adae %>% filter(TRTEMFL == "Y") %>% distinct(USUBJID, AEBODSYS, AEDECOD) %>% nrow()

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

glimpse(adae)

saveRDS(adae, "data/adam/adae.rds")
write_xpt(adae, "data/adam/adae.xpt", version = 5, name = "ADAE",
          label = "Adverse Events Analysis Dataset")


# 4. ADTTE - time to first dermatologic event ----------------------------------

# which AEs count as dermatologic?
adae %>%
  filter(TRTEMFL == "Y",
         AEBODSYS == "SKIN AND SUBCUTANEOUS TISSUE DISORDERS" |
           str_detect(AEDECOD, "^APPLICATION SITE")) %>%
  count(AEBODSYS, AEDECOD, sort = TRUE)

# censoring date: last dose + 30 days, or end of study if earlier
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

# checks: one row per safety subject, no zero or negative times
nrow(adtte) == sum(adsl$SAFFL == "Y")
summary(adtte$AVAL)
count(adtte, TRTA, CNSR)
head(adtte)

saveRDS(adtte, "data/adam/adtte.rds")
write_xpt(adtte, "data/adam/adtte.xpt", version = 5, name = "ADTTE",
          label = "Time to Event Analysis Dataset")


# 5. Table 14.1.1 - demographics -----------------------------------------------

trt_levels <- c("Placebo", "Xanomeline Low Dose", "Xanomeline High Dose", "Total")

saf <- filter(adsl, SAFFL == "Y")
dat <- bind_rows(saf, mutate(saf, TRT01A = "Total")) %>%   # add a Total column
  mutate(TRT01A = factor(TRT01A, levels = trt_levels))

bign <- count(dat, TRT01A, name = "N")
bign

cont_stats <- function(var, label, dp = 1, mm_dp = dp) {
  dat %>%
    group_by(TRT01A) %>%
    summarise(
      n           = sprintf("%d", sum(!is.na(.data[[var]]))),
      `Mean (SD)` = paste0(fmt_num(mean(.data[[var]], na.rm = TRUE), dp), " (",
                           fmt_num(sd(.data[[var]], na.rm = TRUE), dp + 1), ")"),
      Median      = fmt_num(median(.data[[var]], na.rm = TRUE), dp),
      `Min, Max`  = paste0(fmt_num(min(.data[[var]], na.rm = TRUE), mm_dp), ", ",
                           fmt_num(max(.data[[var]], na.rm = TRUE), mm_dp)),
      .groups = "drop"
    ) %>%
    pivot_longer(-TRT01A, names_to = "stat") %>%
    pivot_wider(names_from = TRT01A, values_from = value) %>%
    mutate(stat = paste0("  ", stat)) %>%
    { bind_rows(tibble(stat = label), .) }
}

cat_stats <- function(var, label, levels) {
  dat %>%
    filter(!is.na(.data[[var]])) %>%
    count(TRT01A, value = .data[[var]]) %>%
    complete(TRT01A, value = levels, fill = list(n = 0)) %>%
    left_join(bign, by = "TRT01A") %>%
    mutate(cell = n_pct(n, N), value = factor(value, levels = levels)) %>%
    select(TRT01A, value, cell) %>%
    pivot_wider(names_from = TRT01A, values_from = cell) %>%
    arrange(value) %>%
    mutate(stat = paste0("  ", value)) %>%
    select(stat, all_of(trt_levels)) %>%
    { bind_rows(tibble(stat = label), .) }
}

# try one block on its own first
cont_stats("AGE", "Age (years)", mm_dp = 0)

t_demog <- bind_rows(
  cont_stats("AGE", "Age (years)", mm_dp = 0),
  cat_stats("AGEGR1", "Age group, n (%)", c("<65", "65-80", ">80")),
  cat_stats("SEX", "Sex, n (%)", c("F", "M")),
  cat_stats("RACE", "Race, n (%)",
            c("WHITE", "BLACK OR AFRICAN AMERICAN", "AMERICAN INDIAN OR ALASKA NATIVE")),
  cont_stats("WEIGHTBL", "Baseline weight (kg)"),
  cont_stats("HEIGHTBL", "Baseline height (cm)"),
  cont_stats("BMIBL", "Baseline BMI (kg/m2)")
) %>%
  mutate(across(everything(), ~ replace_na(.x, "")))

names(t_demog) <- c("", paste0(trt_levels, "\n(N=", bign$N, ")"))
print(t_demog, n = Inf)

write_txt_table(
  t_demog, "output/t_demog.txt",
  titles = c("Table 14.1.1",
             "Demographic and Baseline Characteristics",
             "Safety Population"),
  footnotes = c("Percentages are based on the number of subjects in each treatment group.",
                "Source: ADSL. Program: programs/R/t_demog.R")
)


# 6. Table 14.3.1 - TEAEs by SOC and PT ----------------------------------------

add_total <- function(df) {
  bind_rows(df, mutate(df, TRTA = "Total")) %>%
    mutate(TRTA = factor(TRTA, levels = trt_levels))
}

bign_ae <- saf %>%
  rename(TRTA = TRT01A) %>%
  add_total() %>%
  count(TRTA, name = "N")

teae <- adae %>%
  filter(SAFFL == "Y", TRTEMFL == "Y") %>%
  add_total()

# a subject is counted once per row, however many times they had the event
count_subj <- function(df, vars = character()) {
  df %>%
    distinct(TRTA, USUBJID, across(all_of(vars))) %>%
    count(TRTA, across(all_of(vars))) %>%
    complete(TRTA, nesting(!!!syms(vars)), fill = list(n = 0))
}

any_ae <- count_subj(teae)
by_soc <- count_subj(teae, "AEBODSYS") %>% mutate(AEDECOD = "")
by_pt  <- count_subj(teae, c("AEBODSYS", "AEDECOD"))

any_ae
head(by_soc)

# sort by descending Total frequency
soc_order <- by_soc %>% filter(TRTA == "Total") %>% select(AEBODSYS, soc_n = n)
pt_order  <- by_pt  %>% filter(TRTA == "Total") %>% select(AEBODSYS, AEDECOD, pt_n = n)

t_ae <- bind_rows(by_soc, by_pt) %>%
  left_join(bign_ae, by = "TRTA") %>%
  mutate(cell = n_pct(n, N)) %>%
  select(-n, -N) %>%
  pivot_wider(names_from = TRTA, values_from = cell) %>%
  left_join(soc_order, by = "AEBODSYS") %>%
  left_join(pt_order, by = c("AEBODSYS", "AEDECOD")) %>%
  mutate(pt_n = if_else(AEDECOD == "", Inf, pt_n)) %>%
  arrange(desc(soc_n), AEBODSYS, desc(pt_n), AEDECOD) %>%
  mutate(label = if_else(AEDECOD == "", AEBODSYS, paste0("  ", AEDECOD))) %>%
  select(label, all_of(trt_levels))

any_row <- any_ae %>%
  left_join(bign_ae, by = "TRTA") %>%
  mutate(cell = n_pct(n, N)) %>%
  select(TRTA, cell) %>%
  pivot_wider(names_from = TRTA, values_from = cell) %>%
  mutate(label = "Subjects with at least one TEAE") %>%
  select(label, all_of(trt_levels))

t_ae <- bind_rows(any_row, t_ae)
names(t_ae) <- c("System Organ Class\n  Preferred Term",
                 paste0(trt_levels, "\n(N=", bign_ae$N, ")"))
head(t_ae, 15)

write_txt_table(
  t_ae, "output/t_ae.txt",
  first_width = 72,
  titles = c("Table 14.3.1",
             "Treatment-Emergent Adverse Events by System Organ Class and Preferred Term",
             "Safety Population"),
  footnotes = c("TEAE: adverse event starting on or after first dose and up to 30 days after last dose.",
                "A subject is counted once per system organ class and once per preferred term.",
                "Source: ADAE. Program: programs/R/t_ae.R")
)


# 7. Figure 14.2.1 - Kaplan-Meier ----------------------------------------------

tte <- adtte %>%
  filter(PARAMCD == "TTDE", SAFFL == "Y") %>%
  mutate(
    TRTA  = factor(TRTA, levels = c("Placebo", "Xanomeline Low Dose", "Xanomeline High Dose")),
    EVENT = 1 - CNSR               # survival package wants 1 = event
  )

table(tte$TRTA, tte$EVENT)

fit <- survfit(Surv(AVAL, EVENT) ~ TRTA, data = tte)
fit
summary(fit, times = c(30, 60, 90, 180))

lr <- survdiff(Surv(AVAL, EVENT) ~ TRTA, data = tte)
lr
lr_p <- pchisq(lr$chisq, df = length(lr$n) - 1, lower.tail = FALSE)

cox <- coxph(Surv(AVAL, EVENT) ~ TRTA, data = tte)
summary(cox)
cox.zph(cox)                       # proportional hazards check

# quick base-R plot first, before the formatted one
plot(fit, col = 1:3, xlab = "Days", ylab = "Survival probability")

## formatted KM plot with number at risk
strata_names <- sub("TRTA=", "", names(fit$strata))
km <- data.frame(
  time = fit$time,
  surv = fit$surv,
  cens = fit$n.censor,
  TRTA = rep(strata_names, fit$strata)
)
km <- bind_rows(data.frame(time = 0, surv = 1, cens = 0, TRTA = strata_names), km) %>%
  mutate(TRTA = factor(TRTA, levels = levels(tte$TRTA))) %>%
  arrange(TRTA, time)

cols   <- c("Placebo" = "#4D4D4D", "Xanomeline Low Dose" = "#2C7FB8",
            "Xanomeline High Dose" = "#D95F0E")
breaks <- seq(0, 210, by = 30)

p_km <- ggplot(km, aes(time, surv, colour = TRTA)) +
  geom_step(linewidth = 0.7) +
  geom_point(data = filter(km, cens > 0), shape = 3, size = 1.5) +
  scale_colour_manual(values = cols, name = NULL) +
  scale_x_continuous(breaks = breaks, limits = c(0, 210)) +
  scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
  annotate("text", x = 150, y = 0.95, size = 3.5,
           label = sprintf("Log-rank p %s", format.pval(lr_p, digits = 3, eps = 0.001))) +
  labs(x = "Days since first dose",
       y = "Probability of no dermatologic event",
       title = "Time to First Dermatologic Event",
       subtitle = "Kaplan-Meier estimates, safety population (+ = censored)") +
  theme_bw(base_size = 11) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank())

risk <- summary(fit, times = breaks, extend = TRUE)
nrisk <- data.frame(
  time = risk$time,
  n    = risk$n.risk,
  TRTA = factor(sub("TRTA=", "", risk$strata), levels = rev(levels(tte$TRTA)))
)

p_risk <- ggplot(nrisk, aes(time, TRTA, label = n, colour = TRTA)) +
  geom_text(size = 3.3) +
  scale_colour_manual(values = cols, guide = "none") +
  scale_x_continuous(breaks = breaks, limits = c(0, 210)) +
  labs(x = NULL, y = NULL, title = "Number at risk") +
  theme_minimal(base_size = 10) +
  theme(panel.grid = element_blank(), axis.text.x = element_blank(),
        plot.title = element_text(size = 10))

p <- p_km / p_risk + plot_layout(heights = c(4, 1))
p
ggsave("output/f_km.png", p, width = 8, height = 6.5, dpi = 150)

## stats file to go with the figure
med <- summary(fit)$table[, c("records", "events", "median", "0.95LCL", "0.95UCL")]
hr  <- summary(cox)$conf.int[, c(1, 3, 4), drop = FALSE]

sink("output/f_km_stats.txt")
cat("Time to first dermatologic event - safety population\n\n")
cat("Median time to event (days) with 95% CI\n")
print(round(med, 1))
cat("\nLog-rank test: chi-square =", round(lr$chisq, 2), "on", length(lr$n) - 1,
    "df, p =", format.pval(lr_p, digits = 3, eps = 0.001), "\n")
cat("\nCox model, hazard ratio vs placebo (95% CI)\n")
print(round(hr, 2))
cat("\nProportional hazards check (Schoenfeld residuals)\n")
print(cox.zph(cox)$table)
sink()


# 8. QC against SAS (after running the SAS programs) ---------------------------

# download data/adam/sas/*.xpt from SAS OnDemand first, then:
# source("programs/R/qc_compare.R")

list.files("output")
sessionInfo()
