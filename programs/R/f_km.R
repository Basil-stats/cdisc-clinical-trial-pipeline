#-------------------------------------------------------------------------------
# Program  : f_km.R
# Purpose  : Figure 14.2.1 - Kaplan-Meier plot of time to first dermatologic
#            event, with number at risk and log-rank test (safety population)
# Input    : data/adam/adtte.rds
# Output   : output/f_km.png, output/f_km_stats.txt
# Author   : Basil E
#-------------------------------------------------------------------------------

library(dplyr)
library(survival)
library(ggplot2)
library(patchwork)

adtte <- readRDS("data/adam/adtte.rds") %>%
  filter(PARAMCD == "TTDE", SAFFL == "Y") %>%
  mutate(
    TRTA  = factor(TRTA, levels = c("Placebo", "Xanomeline Low Dose", "Xanomeline High Dose")),
    EVENT = 1 - CNSR
  )

fit <- survfit(Surv(AVAL, EVENT) ~ TRTA, data = adtte)
lr  <- survdiff(Surv(AVAL, EVENT) ~ TRTA, data = adtte)
lr_p <- pchisq(lr$chisq, df = length(lr$n) - 1, lower.tail = FALSE)

cox <- coxph(Surv(AVAL, EVENT) ~ TRTA, data = adtte)

# KM curve data (add time 0 so each curve starts at 1)
strata_names <- sub("TRTA=", "", names(fit$strata))
km <- data.frame(
  time  = fit$time,
  surv  = fit$surv,
  cens  = fit$n.censor,
  TRTA  = rep(strata_names, fit$strata)
)
km <- bind_rows(data.frame(time = 0, surv = 1, cens = 0, TRTA = strata_names), km) %>%
  mutate(TRTA = factor(TRTA, levels = levels(adtte$TRTA))) %>%
  arrange(TRTA, time)

cols <- c("Placebo" = "#4D4D4D", "Xanomeline Low Dose" = "#2C7FB8",
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

# number at risk
risk <- summary(fit, times = breaks, extend = TRUE)
nrisk <- data.frame(
  time = risk$time,
  n    = risk$n.risk,
  TRTA = factor(sub("TRTA=", "", risk$strata), levels = rev(levels(adtte$TRTA)))
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
ggsave("output/f_km.png", p, width = 8, height = 6.5, dpi = 150)

# summary statistics to go with the figure
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
