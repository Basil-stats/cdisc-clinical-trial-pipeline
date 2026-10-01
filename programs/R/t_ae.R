#-------------------------------------------------------------------------------
# Program  : t_ae.R
# Purpose  : Table 14.3.1 - Treatment-emergent adverse events by system organ
#            class and preferred term (safety population)
# Input    : data/adam/adsl.rds, data/adam/adae.rds
# Output   : output/t_ae.txt
# Author   : Basil E
#-------------------------------------------------------------------------------

library(dplyr)
library(tidyr)
library(rlang)

source("programs/R/utils.R")

trt_levels <- c("Placebo", "Xanomeline Low Dose", "Xanomeline High Dose", "Total")

adsl <- readRDS("data/adam/adsl.rds") %>% filter(SAFFL == "Y")
teae <- readRDS("data/adam/adae.rds") %>% filter(SAFFL == "Y", TRTEMFL == "Y")

add_total <- function(df) {
  bind_rows(df, mutate(df, TRTA = "Total")) %>%
    mutate(TRTA = factor(TRTA, levels = trt_levels))
}

bign <- adsl %>%
  rename(TRTA = TRT01A) %>%
  add_total() %>%
  count(TRTA, name = "N")

teae <- add_total(teae)

# subjects counted once per row
count_subj <- function(df, vars = character()) {
  df %>%
    distinct(TRTA, USUBJID, across(all_of(vars))) %>%
    count(TRTA, across(all_of(vars))) %>%
    complete(TRTA, nesting(!!!syms(vars)), fill = list(n = 0))
}

any_ae <- count_subj(teae)
by_soc <- count_subj(teae, "AEBODSYS") %>% mutate(AEDECOD = "")
by_pt  <- count_subj(teae, c("AEBODSYS", "AEDECOD"))

# sort SOCs, and PTs within SOC, by descending total frequency
soc_order <- by_soc %>% filter(TRTA == "Total") %>% select(AEBODSYS, soc_n = n)
pt_order  <- by_pt  %>% filter(TRTA == "Total") %>% select(AEBODSYS, AEDECOD, pt_n = n)

tbl <- bind_rows(by_soc, by_pt) %>%
  left_join(bign, by = "TRTA") %>%
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
  left_join(bign, by = "TRTA") %>%
  mutate(cell = n_pct(n, N)) %>%
  select(TRTA, cell) %>%
  pivot_wider(names_from = TRTA, values_from = cell) %>%
  mutate(label = "Subjects with at least one TEAE") %>%
  select(label, all_of(trt_levels))

tbl <- bind_rows(any_row, tbl)
names(tbl) <- c("System Organ Class\n  Preferred Term",
                paste0(trt_levels, "\n(N=", bign$N, ")"))

write_txt_table(
  tbl, "output/t_ae.txt",
  first_width = 60,
  titles = c("Table 14.3.1",
             "Treatment-Emergent Adverse Events by System Organ Class and Preferred Term",
             "Safety Population"),
  footnotes = c("TEAE: adverse event starting on or after first dose and up to 30 days after last dose.",
                "A subject is counted once per system organ class and once per preferred term.",
                "Source: ADAE. Program: programs/R/t_ae.R")
)
