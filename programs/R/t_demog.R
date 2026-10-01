#-------------------------------------------------------------------------------
# Program  : t_demog.R
# Purpose  : Table 14.1.1 - Demographic and baseline characteristics
#            (safety population, by actual treatment)
# Input    : data/adam/adsl.rds
# Output   : output/t_demog.txt
# Author   : Basil E
#-------------------------------------------------------------------------------

library(dplyr)
library(tidyr)

source("programs/R/utils.R")

adsl <- readRDS("data/adam/adsl.rds") %>% filter(SAFFL == "Y")

trt_levels <- c("Placebo", "Xanomeline Low Dose", "Xanomeline High Dose", "Total")

# add a "Total" copy of every subject
dat <- bind_rows(adsl, mutate(adsl, TRT01A = "Total")) %>%
  mutate(TRT01A = factor(TRT01A, levels = trt_levels))

bign <- count(dat, TRT01A, name = "N")

cont_stats <- function(var, label, dp = 1, mm_dp = dp) {
  dat %>%
    group_by(TRT01A) %>%
    summarise(
      n           = sprintf("%d", sum(!is.na(.data[[var]]))),
      `Mean (SD)` = sprintf(paste0("%.", dp, "f (%.", dp + 1, "f)"),
                            mean(.data[[var]], na.rm = TRUE), sd(.data[[var]], na.rm = TRUE)),
      Median      = sprintf(paste0("%.", dp, "f"), median(.data[[var]], na.rm = TRUE)),
      `Min, Max`  = sprintf(paste0("%.", mm_dp, "f, %.", mm_dp, "f"),
                            min(.data[[var]], na.rm = TRUE), max(.data[[var]], na.rm = TRUE)),
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

tbl <- bind_rows(
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

hdr <- paste0(trt_levels, "\n(N=", bign$N, ")")
names(tbl) <- c("", hdr)

write_txt_table(
  tbl, "output/t_demog.txt",
  titles = c("Table 14.1.1",
             "Demographic and Baseline Characteristics",
             "Safety Population"),
  footnotes = c("Percentages are based on the number of subjects in each treatment group.",
                "Source: ADSL. Program: programs/R/t_demog.R")
)
