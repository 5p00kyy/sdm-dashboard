#!/usr/bin/env Rscript
# Compatibility entry point for the recovered SDM project.
# The original heavy INLA/PointedSDMs script was deleted with the directory; this
# recreated entry point runs the optimized workflow used by the web app.

cmd_args <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
if (length(file_arg) > 0) {
  main_path <- normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = TRUE)
  setwd(dirname(main_path))
}

source("pipeline.R")
