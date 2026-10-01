#-------------------------------------------------------------------------------
# Program  : 00_export_sdtm.R
# Purpose  : Export the CDISC pilot SDTM domains used in this project to SAS
#            transport files, so the R and SAS programs read identical inputs
# Input    : pharmaversesdtm (dm, ex, ds, ae, vs)
# Output   : data/sdtm/*.xpt
# Author   : Basil E
#-------------------------------------------------------------------------------

library(pharmaversesdtm)
library(haven)

domains <- c("dm", "ex", "ds", "ae", "vs")

for (d in domains) {
  df <- get(d, envir = asNamespace("pharmaversesdtm"))
  write_xpt(df, file.path("data/sdtm", paste0(d, ".xpt")),
            version = 5, name = toupper(d))
  message(d, ": ", nrow(df), " records")
}
