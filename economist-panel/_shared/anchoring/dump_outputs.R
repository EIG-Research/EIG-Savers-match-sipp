# Dump regenerated hybrid outputs for spec-prose update.
suppressMessages({library(readxl); library(arrow)}); options(scipen = 999, width = 200)
cat("===== HEADLINE =====\n"); print(as.data.frame(read_excel("output/tables/universal_sm_hybrid/hybrid_headline.xlsx")))
cat("\n===== BY ROUTE =====\n"); print(as.data.frame(read_excel("output/tables/universal_sm_hybrid/hybrid_by_route.xlsx")))
cat("\n===== DISTRIBUTIONAL INCIDENCE (sheets) =====\n")
for (sh in excel_sheets("output/tables/universal_sm_hybrid/hybrid_distributional_incidence.xlsx")) {
  cat("\n--- sheet:", sh, "---\n"); print(as.data.frame(read_excel("output/tables/universal_sm_hybrid/hybrid_distributional_incidence.xlsx", sheet = sh)))
}
cat("\n===== PIVOT TABLE =====\n"); print(as.data.frame(read_parquet("data/processed/universal_sm_hybrid/pivot_table.parquet")))
