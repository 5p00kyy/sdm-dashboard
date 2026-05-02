#!/usr/bin/env Rscript
# Optimized command-line pipeline for the recovered SDM project.

cmd_args <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
if (length(file_arg) > 0) {
  pipeline_path <- normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = TRUE)
  setwd(dirname(pipeline_path))
}

source("R/optimized_sdm.R")
source("R/load.R")

n_cores <- max(1L, detect_available_cores(TRUE) - 1L)

occ_file <- if (file.exists("presence_data.csv")) "presence_data.csv" else NA_character_
if (is.na(occ_file)) {
  stop("presence_data.csv was not found. Restore it or run the Shiny app and upload a CSV.", call. = FALSE)
}

cat("═══════════════════════════════════════════════════════════════\n")
cat("  Optimized SDM Pipeline\n")
cat("═══════════════════════════════════════════════════════════════\n\n")

result <- run_fast_sdm(
  species = "Piper aduncum",
  occurrence_file = occ_file,
  worldclim_dir = "Worldclim",
  selected_biovars = c(1, 4, 6, 12, 15, 18),
  projection_extent = c(112, 155, -45, -10),
  background_n = 10000,
  min_source_records = 15,
  merge_small_sources = TRUE,
  thinning_method = "cell",
  include_quadratic = TRUE,
  threshold = 0.5,
  aggregation_factor = 1,
  cv_folds = 3,
  n_cores = n_cores,
  allow_download = TRUE,
  worldclim_res = 10,
  output_dir = "outputs",
  seed = 42
)

cat("\nRun complete.\n")
cat(sprintf("CPU cores used: %d\n", result$metrics$n_cores))
cat(sprintf("Records used: %s\n", format(result$metrics$presence_records, big.mark = ",")))
cat(sprintf("Cross-validation AUC: %.3f\n", result$metrics$auc_mean))
cat(sprintf("Mean suitability: %.3f\n", result$summary$mean))
cat(sprintf("Max suitability: %.3f\n", result$summary$max))
cat(sprintf("GeoTIFF: %s\n", result$paths$tif))
cat(sprintf("PNG map: %s\n", result$paths$png))
cat(sprintf("Report: %s\n", result$report_text))
