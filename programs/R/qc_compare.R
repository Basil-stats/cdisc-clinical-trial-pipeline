#-------------------------------------------------------------------------------
# Program  : qc_compare.R
# Purpose  : Second view of the double-programming QC - compare the R ADaM
#            datasets with the SAS versions exported to data/adam/sas/*.xpt
# Output   : qc/qc_compare_r.txt
# Author   : Basil E
# Note     : run after the SAS programs, once the SAS .xpt files have been
#            downloaded into data/adam/sas/
#-------------------------------------------------------------------------------

library(haven)
library(diffdf)

compare_one <- function(ds, keys) {
  sas_file <- file.path("data/adam/sas", paste0(ds, ".xpt"))
  if (!file.exists(sas_file)) {
    return(paste(toupper(ds), ": SAS file not found -", sas_file))
  }
  r   <- read_xpt(file.path("data/adam", paste0(ds, ".xpt")))
  sas <- read_xpt(sas_file)

  # blanks vs NA and labels are not real differences
  clean <- function(df) {
    df[] <- lapply(df, function(x) {
      attributes(x) <- attributes(x)[intersect(names(attributes(x)), "class")]
      if (is.character(x)) x[is.na(x)] <- ""
      x
    })
    df
  }

  res <- diffdf(clean(sas), clean(r), keys = keys, tolerance = 1e-8,
                suppress_warnings = TRUE)
  c(paste0("==== ", toupper(ds), " (base = SAS, compare = R) ===="),
    if (diffdf_has_issues(res)) capture.output(print(res)) else "No differences found.",
    "")
}

out <- c(
  paste("QC run:", format(Sys.time(), "%Y-%m-%d %H:%M")),
  "",
  compare_one("adsl",  "USUBJID"),
  compare_one("adae",  c("USUBJID", "AESEQ")),
  compare_one("adtte", c("USUBJID", "PARAMCD"))
)

writeLines(out, "qc/qc_compare_r.txt")
cat(out, sep = "\n")
