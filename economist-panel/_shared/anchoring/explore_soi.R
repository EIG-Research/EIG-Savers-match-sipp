# Explore IRS SOI Table 1.2 (TY2023) structure to locate the single-filer AGI distribution.
suppressMessages(library(readxl))
f <- "data/raw/irs_soi/23in12ms.xls"
d <- suppressMessages(read_excel(f, sheet = 1, col_names = FALSE))
cat("dims:", nrow(d), "x", ncol(d), "\n\n")

# Row labels in column 1
lab <- gsub("[\r\n]+", " ", as.character(d[[1]]))
cat("=== Column-1 row labels (non-empty) ===\n")
for (i in seq_len(nrow(d))) {
  s <- trimws(lab[i])
  if (!is.na(s) && nchar(s) > 0) cat(sprintf("%3d | %s\n", i, substr(s, 1, 50)))
}

cat("\n=== Row 3 group headers across columns ===\n")
r3 <- gsub("[\r\n]+", " ", as.character(unlist(d[3, ])))
for (j in seq_along(r3)) if (!is.na(r3[j]) && nchar(trimws(r3[j])) > 0) cat(sprintf("col %2d | %s\n", j, substr(r3[j], 1, 45)))
