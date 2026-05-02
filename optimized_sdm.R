# Root-level compatibility loader.
# Prefer R/optimized_sdm.R; this file exists so older launch paths still work.

engine_file <- file.path("R", "optimized_sdm.R")
if (!file.exists(engine_file)) {
  stop("R/optimized_sdm.R was not found. Re-extract the full SDM project folder.", call. = FALSE)
}
source(engine_file)
