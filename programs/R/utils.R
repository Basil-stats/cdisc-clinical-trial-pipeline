#-------------------------------------------------------------------------------
# Program  : utils.R
# Purpose  : Small helper functions shared by the R programs
# Author   : Basil E
#-------------------------------------------------------------------------------

# attach variable labels from a named character vector (needed for the .xpt)
add_labels <- function(df, labels) {
  for (v in intersect(names(labels), names(df))) {
    attr(df[[v]], "label") <- labels[[v]]
  }
  df
}

# round half up (6.25 -> 6.3), the convention SAS uses. base R round() and
# sprintf() round exact halves to the even digit (6.25 -> 6.2)
round_half_up <- function(x, digits = 0) {
  m <- 10^digits
  sign(x) * floor(abs(x) * m + 0.5 + 1e-9) / m
}

# format a number to fixed decimals using round_half_up
fmt_num <- function(x, digits) sprintf(paste0("%.", digits, "f"), round_half_up(x, digits))

# "n (pct)" in the usual table format
n_pct <- function(n, denom) {
  ifelse(denom > 0,
         sprintf("%3d (%5s)", n, fmt_num(100 * n / denom, 1)),
         sprintf("%3d", n))
}

# write a data frame as a fixed-width text table with titles and footnotes.
# column names can contain "\n" for a two-line header
write_txt_table <- function(df, file, titles, footnotes = NULL,
                            first_width = 45, col_width = 24) {
  widths <- c(first_width, rep(col_width, ncol(df) - 1))

  fmt_row <- function(x) {
    cells <- mapply(function(v, w) formatC(v, width = w), x[-1], widths[-1])
    paste0(formatC(x[1], width = -widths[1]), paste(cells, collapse = ""))
  }

  hdr <- strsplit(names(df), "\n")
  n_hdr <- max(lengths(hdr))
  hdr_rows <- sapply(seq_len(n_hdr), function(i) {
    fmt_row(sapply(hdr, function(h) if (length(h) >= i) h[i] else ""))
  })

  line <- strrep("-", sum(widths))
  out <- c(titles, "", line, hdr_rows, line,
           apply(as.matrix(df), 1, fmt_row), line, footnotes)
  writeLines(out, file)
  invisible(out)
}
