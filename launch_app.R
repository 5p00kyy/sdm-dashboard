# Cross-platform launcher for the SDM Shiny app.
# This is friendlier than running app.R directly because it opens the browser.

# Ensure relative paths work even if Rscript is called from another folder.
cmd_args <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
if (length(file_arg) > 0) {
  launcher_path <- normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = TRUE)
  setwd(dirname(launcher_path))
}

if (!file.exists("app.R")) {
  stop("app.R was not found. Run this launcher from the extracted SDM project folder.")
}

source("app.R")

port <- as.integer(Sys.getenv("PORT", "3838"))
host <- Sys.getenv("HOST", "127.0.0.1")

message("Starting SDM Web Interface...")
message("If the browser does not open, go to: http://127.0.0.1:", port)

shiny::runApp(
  shiny::shinyApp(ui, server),
  host = host,
  port = port,
  launch.browser = function(url) utils::browseURL(url)
)
