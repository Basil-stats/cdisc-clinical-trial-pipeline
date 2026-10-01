install.packages(c("admiral", "pharmaversesdtm", "pharmaverseadam", "metacore", "metatools", 
                   "xportr", "Tplyr", "rtables", "diffdf", "survival", "ggsurvfit"))

programs <- c(
  "00_export_sdtm.R",
  "adsl.R",
  "adae.R",
  "adtte.R",
  "t_demog.R",
  "t_ae.R",
  "f_km.R"
)

for (p in programs) {
  message("---- ", p)
  source(file.path("programs/R", p), echo = FALSE)
}

# qc_compare.R is run separately, after the SAS datasets are available
sessionInfo()
