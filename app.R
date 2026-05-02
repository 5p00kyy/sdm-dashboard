# User-friendly web interface for the SDM project
# Run with: Rscript app.R

cmd_args <- commandArgs(FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
if (length(file_arg) > 0) {
  app_path <- normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = TRUE)
  setwd(dirname(app_path))
} else {
  app_ofiles <- vapply(sys.frames(), function(frame) {
    if (!is.null(frame$ofile)) frame$ofile else NA_character_
  }, character(1))
  app_ofiles <- app_ofiles[!is.na(app_ofiles) & basename(app_ofiles) == "app.R"]
  if (length(app_ofiles) > 0) {
    app_path <- normalizePath(app_ofiles[length(app_ofiles)], winslash = "/", mustWork = TRUE)
    setwd(dirname(app_path))
  }
}

# Load the modelling engine. R/optimized_sdm.R is now a compatibility loader
# for the refactored modules; the root file remains as an older launch fallback.
engine_candidates <- unique(c(
  file.path("R", "optimized_sdm.R"),
  "optimized_sdm.R",
  file.path(dirname(normalizePath("app.R", winslash = "/", mustWork = FALSE)), "R", "optimized_sdm.R"),
  file.path(dirname(normalizePath("app.R", winslash = "/", mustWork = FALSE)), "optimized_sdm.R")
))
engine_file <- engine_candidates[file.exists(engine_candidates)][1]
if (is.na(engine_file)) {
  stop(
    "Could not find the modelling engine file optimized_sdm.R.\n",
    "Expected either R/optimized_sdm.R or optimized_sdm.R in the same folder as app.R.\n",
    "Your zip/extraction is incomplete. Re-extract the full SDM folder or copy the missing R folder."
  )
}
source(engine_file)
source("R/packages.R")
source("R/load.R")
default_cores <- max(1L, detect_available_cores(TRUE) - 1L)
ensure_sdm_packages(c("shiny", "bslib", "terra"), n_cores = default_cores)

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
})

options(shiny.maxRequestSize = 300 * 1024^2)

ui <- fluidPage(
  theme = bslib::bs_theme(version = 5, bootswatch = "darkly", primary = "#0B6E69"),
  tags$head(tags$style(HTML("\n    .hero { background: linear-gradient(135deg,#0B6E69 0%,#174A7C 100%); color:white; border-radius:18px; padding:28px 32px; margin:18px 0 20px; box-shadow:0 12px 28px rgba(0,0,0,.3);}\n    .hero h1 { font-weight:800; margin:0 0 8px; } .hero p { margin:0; opacity:.92; font-size:1.05rem; }\n    .control-panel,.content-card,.metric-card { background:#272c30; border-radius:16px; box-shadow:0 10px 24px rgba(0,0,0,.3); }\n    .control-panel { padding:18px; } .content-card { padding:18px; margin-bottom:16px; }\n    .metric-grid { display:grid; grid-template-columns:repeat(4,minmax(150px,1fr)); gap:14px; margin-bottom:16px; }\n    .metric-card { border-left:5px solid #0B6E69; padding:16px; } .metric-label { color:#8b9daa; font-size:.83rem; text-transform:uppercase; letter-spacing:.05em; }\n    .metric-value { color:#e8eaed; font-size:1.75rem; font-weight:800; line-height:1.2; }\n    .metric-note { color:#8b9daa; font-size:.85rem; margin-top:4px; }\n    .status-ok,.status-warn,.status-error { border-radius:12px; padding:12px 14px; margin-bottom:16px; }\n    .status-ok { background:#1a3d35; border:1px solid #2d6a5c; color:#7dd3c0; } .status-warn { background:#3d2e10; border:1px solid #665020; color:#f5d98e; } .status-error { background:#3d1816; border:1px solid #6d2624; color:#f5a49a; }\n    pre { background:#0d0f12; color:#d6e4ff; border-radius:12px; padding:14px; } [data-bs-theme=\"dark\"] pre { background:#0d0f12; }\n    .small-muted { color:#6c7a89; font-size:.9rem; }\n    .param-group { background:#1e2125; border-radius:10px; padding:12px; margin:8px 0 12px; border-left:3px solid #4a5568; }\n    .param-group h6 { color:#a0aec0; font-size:.9rem; margin:0 0 10px; font-weight:600; }
    .time-estimate-box { background:#1e2125; border-radius:10px; padding:12px; margin:8px 0 12px; border-left:3px solid #0B6E69; font-size:0.85rem; }
    .time-estimate-box h6 { color:#a0aec0; font-size:.9rem; margin:0 0 8px; font-weight:600; }
    .time-estimate-row { display:flex; justify-content:space-between; padding:3px 0; }
    .time-estimate-model { color:#d6e4ff; }
    .time-estimate-duration { color:#8b9daa; }
    .time-total { border-top:1px solid #4a5568; margin-top:8px; padding-top:8px; font-weight:600; }
    .progress-container { background:#1e2125; border-radius:12px; padding:16px; margin:12px 0; border-left:4px solid #0B6E69; }
    .progress-header { display:flex; justify-content:space-between; align-items:center; margin-bottom:12px; }
    .progress-header h4 { margin:0; color:#d6e4ff; font-size:1rem; }
    .progress-bar-container { background:#0d0f12; border-radius:8px; height:24px; position:relative; margin-bottom:12px; overflow:hidden; }
    .progress-bar { background:linear-gradient(90deg,#0B6E69,#174A7C); height:100%; border-radius:8px; transition:width 0.3s ease; }
    .progress-bar-text { position:absolute; top:50%; left:50%; transform:translate(-50%,-50%); color:#fff; font-weight:600; font-size:0.85rem; text-shadow:0 1px 2px rgba(0,0,0,0.5); }
    .progress-models { display:flex; flex-wrap:wrap; gap:8px; margin-bottom:12px; }
    .progress-model-tag { padding:4px 10px; border-radius:20px; font-size:0.8rem; background:#272c30; }
    .progress-model-tag.running { background:#2d4a2d; color:#7dd3c0; border:1px solid #0B6E69; }
    .progress-model-tag.completed { background:#1a3d35; color:#7dd3c0; }
    .progress-model-tag.pending { background:#3d3a30; color:#8b9daa; }
    .progress-model-tag.failed { background:#3d1816; color:#f5a49a; }
    .progress-detail { color:#8b9daa; font-size:0.85rem; padding:8px; background:#0d0f12; border-radius:6px; margin-top:12px; }
    .progress-complete { background:#1a3d35; border:1px solid #2d6a5c; border-radius:12px; padding:16px; text-align:center; }
    .progress-complete h4 { color:#7dd3c0; margin:0 0 8px; }
    .progress-failed { background:#3d1816; border:1px solid #6d2624; border-radius:12px; padding:16px; }
    .progress-failed h4 { color:#f5a49a; margin:0 0 8px; }
    .stop-button { background:#6d2624; border:1px solid #8a3331; color:#f5a49a; }
    .stop-button:hover { background:#8a3331; }
    @media(max-width:768px){.progress-container{padding:10px;font-size:0.85rem;}.progress-models{display:flex;flex-wrap:nowrap;overflow-x:auto;gap:6px;}}\n    @media(max-width:1100px){.metric-grid{grid-template-columns:repeat(2,minmax(150px,1fr));}} @media(max-width:700px){.metric-grid{grid-template-columns:1fr;}}\n  "))),

  div(class = "hero", h1("Species Distribution Model Web Interface"), p("Fast habitat suitability mapping for presence-only occurrence datasets.")),

  sidebarLayout(
sidebarPanel(width = 3, class = "control-panel",
    h4("1. Input data"),
    conditionalPanel(condition = "input.model_type !== 'ensemble'", checkboxInput("use_biomod2", "Use BIOMOD2 ensemble", value = FALSE))
    checkboxInput("use_bias_corr", "Apply bias correction (BATIS)", value = FALSE),
      textInput("species", "Species name", value = "Piper aduncum"),
      fileInput("occ_file", "Upload occurrence CSV/TSV", accept = c(".csv", ".tsv", ".txt")),
      div(class = "small-muted", "If presence_data.csv exists in the project folder, it is used when no file is uploaded."), br(),
      textInput("worldclim_dir", "WorldClim folder", value = "Worldclim"),
      checkboxInput("download_worldclim", "Download missing WorldClim/elevation layers", value = TRUE),
      selectInput("worldclim_res", "WorldClim resolution", choices = c("10 arc-min" = "10", "5 arc-min" = "5", "2.5 arc-min" = "2.5"), selected = "10"),

      hr(), h4("2. Environmental covariates"),
      checkboxGroupInput("biovars", "Climate variables", choices = biovar_choices, selected = c("1", "4", "6", "12", "15", "18")),
      checkboxInput("use_elevation", "Add elevation from OpenTopography", value = FALSE),
      conditionalPanel("input.use_elevation == true",
        selectInput("elevation_demtype", "Elevation DEM", choices = opentopo_dem_choices, selected = "COP30"),
        passwordInput("opentopo_api_key", "OpenTopography API key (optional)", value = ""),
        div(class = "small-muted", "Leave blank to use OPENTOPOGRAPHY_API_KEY from your environment. Keys are not saved in outputs.")
      ),
      checkboxInput("use_soil", "Add SoilGrids soil covariates", value = FALSE),
      conditionalPanel("input.use_soil == true",
        selectInput("soil_depth", "Soil depth", choices = c("0-30 cm" = "30", "0-60 cm" = "60"), selected = "30"),
        checkboxGroupInput("soil_vars", "Soil properties", choices = soilgrids_soil_choices, selected = soilgrids_default_vars),
        div(class = "small-muted", "Data source: SoilGrids250m (ISRIC). Downloads tiles on demand.")
      ),
      checkboxInput("use_microclimate", "Add MODIS microclimate (LST, NDVI)", value = FALSE),
      conditionalPanel("input.use_microclimate == true",
        numericInput("modis_year_start", "Start year", value = 2020, min = 2000, max = 2024, step = 1),
        numericInput("modis_year_end", "End year", value = 2023, min = 2000, max = 2024, step = 1),
        div(class = "small-muted", "Data source: MODIS LST (MOD11A2/MYD11A2) and NDVI (MOD13Q1) via ORNL web service. No login required.")
      ),

hr(), h4("3. Model configuration"),
        
        h5("3.1 Data sampling"),
        checkboxInput("include_rangebag", "Include Rangebagging in final ensemble (off by default)", value = FALSE),
      numericInput("background_n", "Background points", value = 10000, min = 500, max = 100000, step = 500),
      numericInput("min_source_records", "Merge sources with fewer than", value = 15, min = 1, max = 100, step = 1),
      radioButtons("thinning_method", "Spatial thinning", choices = c("None" = "none", "Grid-based (raster cell)" = "cell", "Distance-based (spThin)" = "distance"), selected = "cell"),
      conditionalPanel("input.thinning_method == 'distance'",
        numericInput("spthin_distance", "Minimum distance (km)", value = 10, min = 1, max = 500, step = 5),
        div(class = "small-muted", "Recommended: 10-50km to reduce spatial autocorrelation")
      ),
      
h5("3.2 Model type"),
        selectInput("model_type", "Model algorithm", choices = c("GLM (logistic regression)" = "glm", "Rangebagging" = "rangebag", "Ensemble (multi-model)" = "ensemble"), selected = "glm"),
        # ---- New model selection checkboxes ----
        h5("Select modeling algorithms"),
        checkboxGroupInput(
          "selected_models",
          "Available models",
          choices = c(
            "GLM (logistic regression)" = "glm",
            "GAM (Generalized Additive Model)" = "gam",
            "Random Forest (Ranger)" = "ranger",
            "MaxEnt (Phillips)" = "maxent",
            "GBM (Boosted Trees)" = "gbm",
            "BIOCLIM (Envelope)" = "bioclim",
            "ANN (Neural Network)" = "nnet",
            "Rangebagging (custom)" = "rangebag"
          ),
          selected = c("glm", "rangebag")
        ),
        div(class = "small-muted", "Select any combination of models. Rangebagging is the only custom algorithm not provided by BIOMOD2."),
      
      conditionalPanel("input.model_type == 'glm'",
        checkboxInput("quadratic", "Include quadratic climate responses", value = TRUE),
        div(class = "small-muted", "Adds polynomial terms to capture non-linear relationships")
      ),
      
      conditionalPanel("input.model_type == 'rangebag'",
        numericInput("n_bags", "Number of bags", value = 100, min = 10, max = 500, step = 10),
        div(class = "small-muted", "More bags = more stable predictions but slower"),
        selectInput("rangebag_dim", "Rangebag dimensions", choices = c("1D (ranges) - default" = "1", "2D (convex hull)" = "2"), selected = "1"),
        checkboxInput("force_2d", "Force 2D (no automatic fallback to 1D)", value = FALSE),
        div(class = "small-muted", "2D uses convex hulls; may fail with small/irregular data"),
        div(class = "small-muted", "Rangebagging works well when occurrence records are sparse or highly clustered.")
      ),
      
conditionalPanel(
  condition = "input.model_type == 'ensemble'",
  h5("3.3 Custom model"),
  checkboxGroupInput(
    "ensemble_models",
    "Custom models to include",
    choices = c("Rangebagging" = "rangebag"),
    selected = "rangebag"
  ),
  div(class = "small-muted", "Rangebagging is the only custom algorithm not provided by BIOMOD2."),
  h5("3.5 Ensemble options"),
  selectInput(
    "ensemble_weighting",
    "Ensemble weighting (applies to BIOMOD2 models)",
    choices = c(
      "TSS-weighted (recommended)" = "tss",
      "AUC-weighted" = "auc",
      "Equal weights" = "equal"
    ),
    selected = "tss"
  ),
  numericInput(
    "tss_threshold",
    "Minimum TSS to include (BIOMOD2 models)",
    value = 0.6,
    min = 0,
    max = 1,
    step = 0.05
  ),
  div(class = "small-muted", "BIOMOD2 models with TSS below this threshold are excluded from the ensemble."),
  radioButtons(
        "display_raster",
        "Map to display",
        choices = c(
          "Weighted ensemble (default)" = "ensemble",
          "GLM" = "GLM",
          "Random Forest" = "RF",
          "MaxEnt (Phillips)" = "MAXENT.Phillips",
          "Rangebagging" = "rangebag"
        ),
        selected = "ensemble"
      ),
),
        div(class = "small-muted", "Includes SD, CV, 95% CI, and model agreement maps")
      ),
      
      checkboxInput("enable_climate_change", "Project future climate", value = FALSE),
      conditionalPanel("input.enable_climate_change == true",
        selectInput("cmip6_ssp", "SSP scenario", choices = c("SSP2-4.5 (moderate)" = "245", "SSP5-8.5 (severe)" = "585"), selected = "585"),
        selectInput("cmip6_time", "Time period", choices = c("2041-2060 (mid-century)" = "2041-2060", "2061-2080 (end-century)" = "2061-2080"), selected = "2061-2080"),
        checkboxGroupInput("cmip6_models", "Climate models (GCM)", choices = c("ACCESS-CM2" = "ACCESS-CM2", "MPI-ESM1-2-HR" = "MPI-ESM1-2-HR", "UKESM1-0-LL" = "UKESM1-0-LL"), selected = "ACCESS-CM2"),
        div(class = "small-muted", "Select one or more. Multiple models will be averaged.")
      ),
      
      hr(), h4("4. Cross-validation"),
      selectInput("cv_folds", "Number of folds", choices = c("3-fold" = "3", "5-fold" = "5", "10-fold" = "10"), selected = "5"),
      selectInput("cv_method", "CV method", choices = c("Random K-fold" = "random", "Spatial block" = "spatial_block"), selected = "random"),
      conditionalPanel("input.cv_method == 'spatial_block'",
        selectInput("block_method", "Block method", choices = c("K-means clustering" = "kmeans", "Latitudinal blocks" = "lat_blocks"), selected = "kmeans"),
        numericInput("n_blocks", "Number of spatial blocks", value = 5, min = 2, max = 10, step = 1)
      ),
      
      hr(), h4("5. Advanced options"),
      checkboxInput("show_advanced", "Show advanced options", value = FALSE),
      conditionalPanel("input.show_advanced == true",
        checkboxInput("enable_tuning", "Enable automatic hyperparameter tuning", value = FALSE),
        div(class = "small-muted", "Tests multiple hyperparameter combinations for each model"),
        checkboxInput("detect_extrapolation", "Detect extrapolation (MESS)", value = TRUE),
        conditionalPanel("input.detect_extrapolation",
          fluidRow(
            column(6, numericInput("mess_threshold_low", "Low threshold", value = 0.3, min = 0, max = 1, step = 0.1)),
            column(6, numericInput("mess_threshold_high", "High threshold", value = 0.7, min = 0, max = 1, step = 0.1))
          )
        ),
        numericInput("n_cores", "CPU cores", value = default_cores, min = 1, max = detect_available_cores(TRUE), step = 1),
        div(class = "small-muted", "Also sets MAKEFLAGS=-jN for source package compilation."),
        numericInput("aggregation_factor", "Raster aggregation (1=native)", value = 1, min = 1, max = 8, step = 1),
        div(class = "small-muted", "Aggregation speeds up large-area projections significantly")
      ),

      hr(), h4("6. Projection"),
      selectInput("extent_preset", "Projection extent", choices = c("World (full)" = "world", "Australia - full" = "aus_full", "Northern Australia" = "aus_north", "Eastern Australia" = "aus_east", "Custom" = "custom"), selected = "world"),
      conditionalPanel("input.extent_preset == 'custom'",
        fluidRow(column(6, numericInput("xmin", "xmin", 112)), column(6, numericInput("xmax", "xmax", 155))),
        fluidRow(column(6, numericInput("ymin", "ymin", -45)), column(6, numericInput("ymax", "ymax", -10)))
      ),
      hr(),
      radioButtons("boundary_type", "Boundary file",
        choices = c("None (rectangular extent)" = "none",
                    "Australia (default)" = "australia",
                    "Upload custom boundary" = "custom"),
        selected = "australia"
      ),
      conditionalPanel("input.boundary_type == 'custom'",
        fileInput("boundary_file", "Upload KML/Shapefile", accept = c(".kml", ".kmz", ".shp", ".shx", ".gpkg")),
        div(class = "small-muted", "Upload a KML, KMZ, Shapefile, or GeoPackage boundary file.")
      ),
      checkboxInput("show_boundary_line", "Show boundary line on map", value = FALSE),
      sliderInput("threshold", "High-risk threshold", min = 0.05, max = 0.95, value = 0.50, step = 0.05),
      hr(),
      uiOutput("time_estimate_display"),
      actionButton("run_model", "Run SDM", class = "btn-primary btn-lg", width = "100%"),
      uiOutput("stop_button_display")
    ),

    mainPanel(width = 9,
      uiOutput("status_banner"), uiOutput("progress_indicator"), uiOutput("metric_cards"),
      tabsetPanel(id = "tabs",
        tabPanel("Dashboard", br(), fluidRow(column(8, div(class = "content-card", plotOutput("suitability_plot", height = "620px"))), column(4, div(class = "content-card", h4("Projection summary"), verbatimTextOutput("summary_text"))))),
        tabPanel("Occurrences", br(), fluidRow(column(7, div(class = "content-card", plotOutput("occurrence_plot", height = "540px"))), column(5, div(class = "content-card", h4("Top data sources"), tableOutput("source_table"))))),
        tabPanel("Model diagnostics", br(), fluidRow(column(7, div(class = "content-card", h4("Coefficient summary"), tableOutput("coef_table"))), column(5, div(class = "content-card", h4("Run log"), verbatimTextOutput("run_log"))))),
        tabPanel("Configuration", br(), div(class = "content-card", uiOutput("config_table"))),
        tabPanel("Climate Change", br(),
          uiOutput("climate_change_tabs")
        ),
        tabPanel("Downloads", br(), div(class = "content-card", h4("Export results"), p("Downloads are enabled after a successful run."), downloadButton("download_tif", "Download GeoTIFF"), downloadButton("download_png", "Download PNG map"), downloadButton("download_occ_png", "Download occurrence map PNG"), downloadButton("download_occ", "Download cleaned occurrences"), downloadButton("download_report", "Download text report"), uiOutput("future_downloads")))
      )
    )
  )
)

server <- function(input, output, session) {
  rv <- reactiveValues(result = NULL, log = "Ready.\n", error = NULL, running = FALSE, stop_requested = FALSE, current_model = NULL, model_status = NULL, model_fold = NULL)
  append_log <- function(message) rv$log <- paste0(rv$log, format(Sys.time(), "%H:%M:%S"), "  ", message, "\n")

  output$time_estimate_display <- renderUI({
    model_types <- if (is.null(input$ensemble_models)) {
      if (input$model_type == "ensemble") c("glm", "ranger", "maxent", "gam", "rangebag") else character(0)
    } else {
      input$ensemble_models
    }

    if (input$model_type == "glm" || input$model_type == "rangebag") {
      model_types <- switch(input$model_type, "glm" = "glm", "rangebag" = "rangebag")
    }

    if (length(model_types) == 0) return(NULL)

    n_folds <- as.integer(input$cv_folds %||% 5)
    bg_n <- as.integer(input$background_n %||% 10000)
    params <- get_model_params(input)

    times_list <- lapply(model_types, function(mt) {
      list(time = estimate_model_time(mt, params[[mt]] %||% list(), n_folds, bg_n), name = toupper(mt))
    })

    total_time <- sum(sapply(times_list, function(x) x$time))
    warning_mark <- get_time_warning(total_time)

    model_rows <- lapply(times_list, function(x) {
      div(class = "time-estimate-row",
        span(class = "time-estimate-model", x$name),
        span(class = "time-estimate-duration", format_time_estimate(x$time))
      )
    })

    div(class = "time-estimate-box",
      h6(paste0("Estimated Training Times ", warning_mark)),
      model_rows,
      div(class = "time-total", paste("Total:", format_time_estimate(total_time)))
    )
  })

  output$stop_button_display <- renderUI({
    if (isTRUE(rv$running)) {
      actionButton("stop_model", "Stop", class = "btn-danger stop-button", width = "100%")
    } else {
      NULL
    }
  })

  observeEvent(input$stop_model, {
    rv$stop_requested <- TRUE
    append_log("Stop requested - will stop after current fold completes...")
  })

  output$status_banner <- renderUI({
    if (isTRUE(rv$running)) div(class = "status-warn", strong("Running model... "), "Large rasters/downloads can take several minutes.")
    else if (!is.null(rv$error)) div(class = "status-error", strong("Run failed: "), rv$error)
    else if (!is.null(rv$result)) div(class = "status-ok", strong("Run complete. "), "Review maps, diagnostics, and downloads below.")
    else div(class = "status-warn", strong("Ready. "), "Upload data or restore presence_data.csv, then click Run SDM.")
  })

  output$progress_indicator <- renderUI({
    if (!isTRUE(rv$running) && is.null(rv$result)) return(NULL)

    if (!is.null(rv$result) && isFALSE(rv$running)) {
      return(div(class = "progress-complete",
        h4("Training Complete!"),
        paste("Total time:", rv$result$metrics$elapsed_seconds, "seconds")
      ))
    }

    if (isTRUE(rv$stop_requested)) {
      return(div(class = "progress-failed",
        h4("Stopped by user"),
        "Model training was stopped. Click Run SDM to start a new run."
      ))
    }

    NULL
  })

  observeEvent(input$run_model, {
    rv$error <- NULL; rv$running <- TRUE; rv$log <- ""
    occurrence_file <- if (!is.null(input$occ_file)) input$occ_file$datapath else if (file.exists("presence_data.csv")) "presence_data.csv" else NULL
    if (is.null(occurrence_file)) {
      rv$error <- "No occurrence file found. Upload a CSV/TSV or restore presence_data.csv."
      append_log(rv$error); rv$running <- FALSE; return(invisible(NULL))
    }
    if (length(input$biovars) < 2) {
      rv$error <- "Select at least two BIOCLIM variables."
      append_log(rv$error); rv$running <- FALSE; return(invisible(NULL))
    }
    if (isTRUE(input$use_soil) && length(input$soil_vars) == 0) {
      rv$error <- "Select at least one HWSD soil property, or turn soil covariates off."
      append_log(rv$error); rv$running <- FALSE; return(invisible(NULL))
    }
    projection_extent <- extent_from_inputs(input)

    boundary_path <- NULL
    if (!is.null(input$boundary_type)) {
      boundary_path <- switch(input$boundary_type,
        "none" = NULL,
        "australia" = file.path("Australia Boundary", "AUS_2021_AUST_GDA2020.shp"),
        "custom" = if (!is.null(input$boundary_file)) input$boundary_file$datapath else NULL
      )
    }

    withProgress(message = "Running SDM", value = 0, {
selected_models <- input$selected_models
        # Map UI model names to BIOMOD2 identifiers
        biomod2_map <- c(
          glm = "GLM",
          gam = "GAM",
          ranger = "RF",
          maxent = "MAXENT.Phillips",
          gbm = "GBM",
          bioclim = "BIOCLIM",
          nnet = "ANN"
        )
        biomod2_sel <- intersect(selected_models, names(biomod2_map))
        biomod2_models <- unname(biomod2_map[biomod2_sel])
        custom_sel <- setdiff(selected_models, names(biomod2_map)) # should contain "rangebag"

        # Initialize empty result list
        result_list <- list()

        # Run BIOMOD2 ensemble if any BIOMOD2 models selected
        if (length(biomod2_models) > 0) {
          biomod_res <- tryCatch(
            run_biomod2(
              occ = occurrence_file,
              env_stack = env$env_train_scaled,
              models = biomod2_models,
              ensemble_weight = input$ensemble_weighting,
              background_n = as.integer(input$background_n),
              cv_folds = as.integer(input$cv_folds),
              seed = 42,
              bias_raster = if (isTRUE(input$use_bias_corr)) bias_raster else NULL,
              log_fun = append_log
            ),
            error = function(e) { append_log(paste("BIOMOD2 error:", conditionMessage(e))); NULL }
          )
          if (!is.null(biomod_res)) result_list$biomod <- biomod_res
        }

        # Run Rangebagging if selected
        if ("rangebag" %in% custom_sel) {
          rangebag_res <- tryCatch(
            run_fast_sdm(
              species = input$species, occurrence_file = occurrence_file, worldclim_dir = input$worldclim_dir,
              selected_biovars = as.integer(input$biovars), projection_extent = projection_extent,
              background_n = input$background_n, min_source_records = input$min_source_records,
              merge_small_sources = TRUE, thinning_method = input$thinning_method, spthin_distance_km = input$spthin_distance,
              model_type = "rangebag", n_bags = input$n_bags,
              d = as.integer(input$rangebag_dim), force_2d = isTRUE(input$force_2d),
              ensemble_weighting = input$ensemble_weighting, tss_threshold = input$tss_threshold,
              include_quadratic = isTRUE(input$quadratic),
              threshold = input$threshold, aggregation_factor = input$aggregation_factor, cv_folds = as.integer(input$cv_folds),
              n_cores = input$n_cores, allow_download = isTRUE(input$download_worldclim), worldclim_res = as.numeric(input$worldclim_res),
              use_elevation = isTRUE(input$use_elevation), elevation_demtype = input$elevation_demtype,
              opentopo_api_key = input$opentopo_api_key,
              use_soil = isTRUE(input$use_soil), soil_depth = as.integer(input$soil_depth), selected_soil_vars = input$soil_vars,
              use_microclimate = isTRUE(input$use_microclimate), modis_year_range = c(as.integer(input$modis_year_start), as.integer(input$modis_year_end)),
              model_types = "rangebag",
              covariate_cache_dir = "covariates",
              boundary_path = boundary_path,
              cv_method = input$cv_method, n_blocks = as.integer(input$n_blocks),
              block_method = input$block_method, enable_tuning = isTRUE(input$enable_tuning),
              output_dir = "outputs", seed = 42, log_fun = append_log,
              progress_fun = function(...) {
                args <- list(...)
                if (length(args) == 1 && is.list(args[[1]]) && !is.null(args[[1]]$type) && args[[1]]$type == "model_progress") {
                  p <- args[[1]]
                  rv$current_model <- p$model
                  rv$model_status <- p$status
                  rv$model_fold <- p$fold
                  incProgress(0.01, detail = paste0(if (!is.null(p$model)) toupper(p$model) else "", " - ", p$status))
                } else {
                  amount <- args[[1]]
                  detail <- if (length(args) > 1) args[[2]] else NULL
                  incProgress(amount %||% 0, detail = detail)
                }
              }
            ),
            error = function(e) { append_log(paste("Rangebag error:", conditionMessage(e))); NULL }
          )
          if (!is.null(rangebag_res)) result_list$rangebag <- rangebag_res
        }

              # After model runs, combine rasters into a final ensemble if needed
      if (length(result_list) > 0) {
        # Compute weighted ensemble raster based on user weighting and include_rangebag flag
        raster_list <- list()
        weight_vec <- c()
        # Add BIOMOD2 model rasters
        if (!is.null(result_list$biomod)) {
          biomod_models <- result_list$biomod$model_rasters
          # Determine weights based on selected scheme
          if (input$ensemble_weighting == "tss") {
            weights <- result_list$biomod$cv_metrics$TSS
          } else if (input$ensemble_weighting == "auc") {
            weights <- result_list$biomod$cv_metrics$AUC
          } else {
            weights <- rep(1, nrow(result_list$biomod$cv_metrics))
          }
          # Normalise weights
          if (sum(weights) > 0) weights <- weights / sum(weights)
          raster_list <- c(raster_list, biomod_models)
          weight_vec <- c(weight_vec, weights)
        }
        # Add Rangebagging raster if user opted in and it ran
        if (isTRUE(input$include_rangebag) && !is.null(result_list$rangebag)) {
          # Use a default weight of 1 for rangebag (or could compute its own metric)
          raster_list <- c(raster_list, list(rangebag = result_list$rangebag$suitability))
          weight_vec <- c(weight_vec, 1)
        }
        if (length(raster_list) > 0) {
          # Stack rasters and compute weighted mean
          stacked <- terra::rast(raster_list)
          # Ensure weights vector matches layers
          weight_vec <- weight_vec / sum(weight_vec)
          ensemble_raster <- terra::app(stacked, fun = function(x) sum(x * weight_vec, na.rm = TRUE))
          result_list$ensemble <- ensemble_raster
          # Populate compatibility fields for downstream UI
          result_list$suitability <- ensemble_raster
          result_list$metrics <- list(
            elapsed_seconds = NA,
            auc_mean = NA,
            cv_folds = as.integer(input$cv_folds),
            n_cores = as.integer(input$n_cores),
            presence_records = NA
          )
        }
        rv$result <- result_list
      } else {
        rv$error <- "No models were successfully run."
      }

    })
    rv$running <- FALSE
  })

  observeEvent(input$run_future_projection, {
    r <- rv$result
    if (is.null(r)) return()
    cmip6_models <- input$cmip6_models
    if (is.null(cmip6_models) || length(cmip6_models) == 0) {
      cmip6_models <- "ACCESS-CM2"
      append_log("No GCM selected, defaulting to ACCESS-CM2")
    }
    append_log("Starting future climate projection...")
    withProgress(message = "Future Climate Projection", value = 0, {
      tryCatch({
        incProgress(0.1, detail = "Loading climate data")
        future_result <- predict_future_suitability(
          r, "Worldclim/future", as.integer(input$biovars), r$config$projection_extent,
          r$config$aggregation_factor, cmip6_models, input$cmip6_ssp, input$cmip6_time,
          input$n_cores, append_log
        )
        r$future <- future_result
        rv$result <- r
        append_log("Future climate projection completed.")
      }, error = function(e) {
        append_log(paste("Future projection failed:", conditionMessage(e)))
      })
    })
  })

  output$metric_cards <- renderUI({
    r <- rv$result
    if (is.null(r)) return(div(class = "metric-grid", metric_card("Records", "-", "waiting for run"), metric_card("Covariates", "-", "waiting for run"), metric_card("AUC", "-", "cross-validation"), metric_card("High-risk area", "-", "km2 above threshold")))
    boundary_note <- if (!is.null(r$boundary)) " (terrestrial)" else ""
    div(class = "metric-grid",
        metric_card("Records used", fmt_num(r$metrics$presence_records), "after cleaning/thinning"),
        metric_card("Covariates", fmt_num(length(r$environment$names)), "climate/elevation/soil"),
        metric_card("CV AUC", fmt_num(r$metrics$auc_mean, 3), paste0(r$metrics$cv_folds, " folds; ", r$metrics$n_cores, " cores")),
        metric_card("High-risk area", fmt_num(r$summary$high_risk_area_km2), paste0("km2", boundary_note))
    )
  })

  output$suitability_plot <- renderPlot({
    if (is.null(rv$result)) return(placeholder_plot("No suitability map yet."))
    r <- rv$result
    # Determine which raster to plot based on user selection
    raster_to_plot <- switch(input$display_raster,
      "ensemble" = if (!is.null(r$ensemble)) r$ensemble else r$biomod$suit_raster,
      "GLM" = r$biomod$model_rasters[["GLM"]],
      "RF" = r$biomod$model_rasters[["RF"]],
      "MAXENT.Phillips" = r$biomod$model_rasters[["MAXENT.Phillips"]],
      "rangebag" = if (!is.null(r$rangebag)) r$rangebag$suitability else NULL,
      NULL)
    if (is.null(raster_to_plot)) return(placeholder_plot("Requested raster not available."))
    plot_suitability_map(raster_to_plot, r$occurrence, r$config$projection_extent, r$config$species, r$config$threshold, TRUE, show_boundary_line = isTRUE(input$show_boundary_line), boundary = r$boundary)
  })
  output$occurrence_plot <- renderPlot({ if (is.null(rv$result)) return(placeholder_plot("No occurrence map yet.")); plot_occurrence_map(rv$result$occurrence, rv$result$config$species) })
  output$summary_text <- renderText({
    r <- rv$result; if (is.null(r)) return("No model has been run yet.")
    extent_label <- if (!is.null(r$boundary)) " (terrestrial/boundary)" else " (full extent)"
    paste("--- Projection Summary", extent_label, "---\n",
          "Mean suitability:", fmt_num(r$summary$mean, 3), "\n",
          "Median suitability:", fmt_num(r$summary$median, 3), "\n",
          "Maximum suitability:", fmt_num(r$summary$max, 3), "\n",
          "Cells above threshold:", fmt_num(r$summary$cells_above_threshold), paste0(" (", fmt_num(r$summary$percent_above_threshold, 1), "%)"), "\n",
          "High-risk area (km2):", fmt_num(r$summary$high_risk_area_km2), "\n\n",
          "Covariates:", paste(r$environment$names, collapse = ", "), "\n",
          "CPU cores used:", r$metrics$n_cores, "\n",
          "Elapsed time (sec):", fmt_num(r$metrics$elapsed_seconds, 1), "\n",
          "Output TIFF:", r$paths$tif, sep = "")
  })
  output$source_table <- renderTable({ r <- rv$result; if (is.null(r)) return(data.frame(Message = "Run the model to view source counts.")); head(data.frame(Source = names(r$source_counts), Records = as.integer(r$source_counts), row.names = NULL), 25) }, striped = TRUE, hover = TRUE, spacing = "s")
  output$coef_table <- renderTable({ r <- rv$result; if (is.null(r)) return(data.frame(Message = "Run the model to view coefficients.")); co <- r$coefficients; numeric_cols <- vapply(co, is.numeric, logical(1)); co[numeric_cols] <- lapply(co[numeric_cols], function(x) signif(x, 4)); co }, striped = TRUE, hover = TRUE, spacing = "s")
  output$run_log <- renderText(rv$log)

  output$config_table <- renderUI({
    r <- rv$result
    if (is.null(r)) return(div(class = "content-card", "Run the model first to view configuration."))

    c <- r$config

    config_rows <- data.frame(
      Parameter = c(
        "Species",
        "Occurrence file",
        "WorldClim directory",
        "BIO variables",
        "Thinning method",
        "Thinning distance (km)",
        "Background points",
        "Min source records",
        "Include quadratic terms",
        "Threshold",
        "Aggregation factor",
        "Cross-validation folds",
        "CPU cores",
        "Projection extent",
        "Boundary file",
        "Use elevation",
        "Use soil",
        "Use microclimate"
      ),
      Value = c(
        c$species,
        c$occurrence_file,
        c$worldclim_dir,
        paste(c$selected_biovars, collapse = ", "),
        switch(c$thinning_method, "none" = "None", "cell" = "Grid-based (raster cell)", "distance" = "Distance-based (spThin)"),
        if (c$thinning_method == "distance") as.character(c$spthin_distance_km) else "N/A",
        as.character(c$background_n),
        as.character(c$min_source_records),
        if (isTRUE(c$include_quadratic)) "Yes" else "No",
        as.character(c$threshold),
        as.character(c$aggregation_factor),
        if (c$cv_folds > 0) as.character(c$cv_folds) else "Off",
        as.character(c$n_cores),
        paste(c$projection_extent, collapse = ", "),
        if (is.null(c$boundary_path) || c$boundary_path == "") "None" else basename(c$boundary_path),
        if (isTRUE(c$use_elevation)) paste("Yes (", c$elevation_demtype, ")", sep = "") else "No",
        if (isTRUE(c$use_soil)) "Yes" else "No",
        if (isTRUE(c$use_microclimate)) paste("Yes (", paste(c$modis_year_range, collapse = "-"), ")", sep = "") else "No"
      ),
      stringsAsFactors = FALSE
    )

    if (c$model_type %in% c("rangebag", "ensemble")) {
      rb_rows <- data.frame(
        Parameter = c("--- Rangebag Settings ---", "Requested dimensions", "Force 2D"),
        Value = c("", paste0(c$d, "D"), if (isTRUE(c$force_2d)) "Yes" else "No"),
        stringsAsFactors = FALSE
      )
      config_rows <- rbind(config_rows, rb_rows)
    }

    if (!is.null(r$dimension_info)) {
      dim_info <- r$dimension_info
      dim_status <- if (dim_info$global_fallback || dim_info$fallback_count > 0) {
        paste0("Yes (", dim_info$fallback_count, " fallbacks)")
      } else {
        "No"
      }
      dim_rows <- data.frame(
        Parameter = c("--- Rangebag Details ---", "Requested dimension", "Actual dimension used", "Fallbacks triggered"),
        Value = c("", dim_info$requested, dim_info$used, dim_status),
        stringsAsFactors = FALSE
      )
      config_rows <- rbind(config_rows, dim_rows)
    }

    if (!is.null(r$future)) {
      f <- r$future
      future_rows <- data.frame(
        Parameter = c("--- Future Climate ---", "GCM models", "SSP scenario", "Time period"),
        Value = c("", paste(f$scenario$models, collapse = ", "), paste0("SSP", f$scenario$ssp), f$scenario$time),
        stringsAsFactors = FALSE
      )
      config_rows <- rbind(config_rows, future_rows)
    }

    tagList(
      h4("Run Configuration"),
      p(class = "small-muted", "Parameter settings used in this model run"),
      renderTable(config_rows, striped = TRUE, hover = TRUE, spacing = "s", rownames = FALSE)
    )
  })

  output$climate_change_tabs <- renderUI({
    r <- rv$result
    if (is.null(r)) {
      return(div(class = "content-card", "Run the SDM model first to enable future climate projections."))
    }
    if (is.null(r$future)) {
      selected_models <- paste(input$cmip6_models, collapse = ", ")
      if (is.null(selected_models) || selected_models == "") selected_models <- "ACCESS-CM2"
      return(div(class = "content-card",
        h4("Future Climate Projection"),
        p("Click below to project species distribution under future climate conditions."),
        p("This will download CMIP6 climate data if not already present (~10MB per scenario)."),
        actionButton("run_future_projection", "Run Future Climate Projection", class = "btn-primary"),
        hr(),
        p(class = "small-muted", "Settings: SSP ", input$cmip6_ssp, ", ", input$cmip6_time, ", GCMs: ", selected_models)
      ))
    }
    f <- r$future
    scenario_text <- paste0(f$scenario$model, ", SSP", f$scenario$ssp, ", ", f$scenario$time)

    accordion_scripts <- NULL
    if (!is.null(f$individual) && length(f$individual$suitabilities) > 1) {
      accordion_scripts <- bslib::accordion(
        open = FALSE,
        bslib::accordion_panel("Individual GCM Maps",
          fluidRow(
            column(4, div(class = "content-card", h5("ACCESS-CM2"), plotOutput("gcm_access_plot", height = "200px"))),
            column(4, div(class = "content-card", h5("MPI-ESM1-2-HR"), plotOutput("gcm_mpi_plot", height = "200px"))),
            column(4, div(class = "content-card", h5("UKESM1-0-LL"), plotOutput("gcm_ukesm_plot", height = "200px")))
          )
        )
      )
    }

    tagList(
      fluidRow(
        column(6, div(class = "content-card", h4("Current climate (1970-2000)"), plotOutput("current_climate_plot", height = "280px"))),
        column(6, div(class = "content-card", h4(paste0("Future climate (", scenario_text, ")")), plotOutput("future_climate_plot", height = "280px"))),
        column(12, div(class = "content-card", h4("Habitat change (future - current)"), plotOutput("delta_climate_plot", height = "300px"),
          h5(paste0("Gain: ", fmt_num(f$delta_summary$cells_above_threshold), " cells above 0 (positive change)"))))
      ),
      if (!is.null(accordion_scripts)) accordion_scripts
    )
  })

  output$current_climate_plot <- renderPlot({
    r <- rv$result
    if (is.null(r) || is.null(r$future)) return(placeholder_plot("No future projection"))
    plot_suitability_map(r$suitability, r$occurrence, r$config$projection_extent, r$config$species, r$config$threshold, TRUE, show_boundary_line = isTRUE(input$show_boundary_line), boundary = r$boundary)
  })

  output$future_climate_plot <- renderPlot({
    r <- rv$result
    if (is.null(r) || is.null(r$future)) return(placeholder_plot("No future projection"))
    plot_suitability_map(r$future$suitability, r$occurrence, r$config$projection_extent, r$config$species, r$config$threshold, TRUE, show_boundary_line = isTRUE(input$show_boundary_line), boundary = r$boundary)
  })

  output$delta_climate_plot <- renderPlot({
    r <- rv$result
    if (is.null(r) || is.null(r$future)) return(placeholder_plot("No future projection"))
    plot_delta_map(r$future$delta, r$config$projection_extent, r$config$species)
  })

  output$gcm_access_plot <- renderPlot({
    r <- rv$result
    if (is.null(r) || is.null(r$future) || is.null(r$future$individual)) return(placeholder_plot("No data"))
    if (!"ACCESS-CM2" %in% names(r$future$individual$suitabilities)) return(placeholder_plot("Not selected"))
    plot_suitability_map(r$future$individual$suitabilities[["ACCESS-CM2"]], r$occurrence, r$config$projection_extent, r$config$species, r$config$threshold, TRUE, show_boundary_line = isTRUE(input$show_boundary_line), boundary = r$boundary)
  })

  output$gcm_mpi_plot <- renderPlot({
    r <- rv$result
    if (is.null(r) || is.null(r$future) || is.null(r$future$individual)) return(placeholder_plot("No data"))
    if (!"MPI-ESM1-2-HR" %in% names(r$future$individual$suitabilities)) return(placeholder_plot("Not selected"))
    plot_suitability_map(r$future$individual$suitabilities[["MPI-ESM1-2-HR"]], r$occurrence, r$config$projection_extent, r$config$species, r$config$threshold, TRUE, show_boundary_line = isTRUE(input$show_boundary_line), boundary = r$boundary)
  })

  output$gcm_ukesm_plot <- renderPlot({
    r <- rv$result
    if (is.null(r) || is.null(r$future) || is.null(r$future$individual)) return(placeholder_plot("No data"))
    if (!"UKESM1-0-LL" %in% names(r$future$individual$suitabilities)) return(placeholder_plot("Not selected"))
    plot_suitability_map(r$future$individual$suitabilities[["UKESM1-0-LL"]], r$occurrence, r$config$projection_extent, r$config$species, r$config$threshold, TRUE, show_boundary_line = isTRUE(input$show_boundary_line), boundary = r$boundary)
  })

  output$future_downloads <- renderUI({
    r <- rv$result
    if (is.null(r) || is.null(r$future)) return(NULL)
    tagList(
      hr(),
      h5("Future Climate Downloads"),
      downloadButton("download_future_tif", "Download future suitability GeoTIFF"),
      downloadButton("download_delta_tif", "Download change (delta) GeoTIFF")
    )
  })

  output$download_future_tif <- downloadHandler(
    filename = function() if (is.null(rv$result$future)) "future_suitability.tif" else basename(rv$result$future$paths$tif),
    content = function(file) { req(rv$result$future, file.exists(rv$result$future$paths$tif)); file.copy(rv$result$future$paths$tif, file, overwrite = TRUE) }
  )

  output$download_delta_tif <- downloadHandler(
    filename = function() if (is.null(rv$result$future)) "delta.tif" else basename(rv$result$future$paths$delta),
    content = function(file) { req(rv$result$future, file.exists(rv$result$future$paths$delta)); file.copy(rv$result$future$paths$delta, file, overwrite = TRUE) }
  )

  output$download_tif <- downloadHandler(filename = function() basename(rv$result$paths$tif), content = function(file) { req(rv$result, file.exists(rv$result$paths$tif)); file.copy(rv$result$paths$tif, file, overwrite = TRUE) })
  output$download_png <- downloadHandler(filename = function() basename(rv$result$paths$png), content = function(file) { req(rv$result, file.exists(rv$result$paths$png)); file.copy(rv$result$paths$png, file, overwrite = TRUE) })
  output$download_occ_png <- downloadHandler(filename = function() basename(rv$result$paths$occ_png), content = function(file) { req(rv$result, file.exists(rv$result$paths$occ_png)); file.copy(rv$result$paths$occ_png, file, overwrite = TRUE) })
  output$download_occ <- downloadHandler(filename = function() paste0(safe_slug(input$species), "_cleaned_occurrences.csv"), content = function(file) { req(rv$result); utils::write.csv(rv$result$occurrence, file, row.names = FALSE) })
  output$download_report <- downloadHandler(filename = function() paste0(safe_slug(input$species), "_sdm_report.txt"), content = function(file) { req(rv$result); write_summary_report(rv$result, file) })
}

if (sys.nframe() == 0) {
  port <- as.integer(Sys.getenv("PORT", "3838"))
  shiny::runApp(shiny::shinyApp(ui, server), host = "0.0.0.0", port = port)
}
