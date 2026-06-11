# Helper (not part of pipeline): locate the SECURE 2.0 sec. 103 Saver's Match
# revenue line in JCT JCX-21-22 (read-only lookup for the assessment text).
suppressPackageStartupMessages(library(pdftools))
txt <- pdf_text("Infrastructure/references/literature/papers/x-21-22_jct_jcx-21-22.pdf")
hits <- grep("[Ss]aver|matching contribution|103", txt)
for (p in hits) {
  lines <- strsplit(txt[p], "\n")[[1]]
  sel <- grep("[Ss]aver", lines, value = TRUE)
  if (length(sel)) { cat("--- page", p, "---\n"); cat(sel, sep = "\n"); cat("\n") }
}
