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

# "n (pct)" in the usual table format
n_pct <- function(n, denom) {
  ifelse(denom > 0, sprintf("%3d (%5.1f)", n, 100 * n / denom), sprintf("%3d", n))
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
