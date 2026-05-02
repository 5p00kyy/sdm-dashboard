# SDM Web Interface

Local R/Shiny app for fast species distribution modelling from presence-only occurrence records. The model uses selected WorldClim BIO layers and can optionally add OpenTopography elevation and HWSD v2 soil covariates.

## What Is Included

- `app.R`: Shiny web interface.
- `R/optimized_sdm.R`: compatibility loader for the refactored engine.
- `R/*.R`: focused modules for packages, occurrence cleaning, covariates, modelling, plotting, reporting, and app helpers.
- `pipeline.R`: command-line runner if `presence_data.csv` is available.
- `launch_app.R`: cross-platform launcher.
- `run_app_windows.bat`: one-click Windows setup and app runner.
- `scripts/download_worldclim.R`: helper to recreate local WorldClim layers.
- `scripts/smoke_test.R`: lightweight source test.
- `data/presence_data_template.csv`: required occurrence CSV template.

## What Is NOT Included (Download Separately)

- **Australia Boundary shapefiles**: Download from [AAS](https://data.gov.au/data/dataset/australian-border-areas) and place in `Australia Boundary/` folder.
- **WorldClim rasters**: App can download automatically, or use `scripts/download_worldclim.R`.
- **Elevation data**: Cached under `covariates/opentopo/` (requires OpenTopography API key).
- **Soil data**: Place HWSD v2 GeoTIFF at `covariates/hwsd_v2/`.
- **`presence_data.csv`**: Your own occurrence data (keep local, never commit).

## Input Data

Occurrence data must include longitude and latitude columns. Accepted names include:

- longitude: `longitude`, `lon`, `decimalLongitude`, or `x`
- latitude: `latitude`, `lat`, `decimalLatitude`, or `y`
- optional source: `source`, `institutionCode`, `provider`, or similar

Put `presence_data.csv` in the project folder for the CLI pipeline, or upload a CSV/TSV in the web app.

## Environmental Covariates

### WorldClim

The app can download missing WorldClim BIO layers when **Download missing WorldClim/elevation layers** is checked.

You can also run:

```bash
Rscript scripts/download_worldclim.R 10
```

### Elevation

Elevation uses the OpenTopography Global DEM API and is cached under `covariates/opentopo/`.

Provide an API key in either place:

- Set environment variable `OPENTOPOGRAPHY_API_KEY`.
- Enter the key in the app field when elevation is enabled.

The key is not written to reports, outputs, or cache metadata.

### Soil

Soil uses a local/cached HWSD v2 GeoTIFF. The recommended source is the HWSD v2 Earth Engine asset:

```text
projects/sat-io/open-datasets/FAO/HWSD_V2_SMU
```

Export the selected HWSD bands to a GeoTIFF and place it at:

```text
covariates/hwsd_v2/HWSD_V2_SMU_selected.tif
```

Supported bands include `TEXTURE_USDA`, `REF_BULK_DENSITY`, `BULK_DENSITY`, `DRAINAGE`, `ROOT_DEPTH`, `AWC`, and `ROOTS`.

### Microclimate (MODIS)

The app can include MODIS microclimate data (Land Surface Temperature and Vegetation Indices) via the ORNL MODIS web service - no login required.

**Data Source**: MODISTools R package (ORNL web service)

**Variables**:
- LST Day (annual mean from MOD11A2)
- LST Night (annual mean from MYD11A2)
- LST Amplitude (Day - Night)
- NDVI (annual mean from MOD13Q1)

**Cache location**: `covariates/microclimate/`

Enable in the app with "Add MODIS microclimate (LST, NDVI)" checkbox.

### Ensemble Modeling

The ensemble model combines multiple algorithms for improved predictions:

- **GLM**: Logistic regression (fast, interpretable)
- **Ranger**: Random Forest (handles non-linear relationships)
- **GAM**: Generalized Additive Model (smoothed relationships)
- **Rangebag**: Range-bagging (convex hull envelopes)

Select models via checkboxes in the app. Default ensemble uses GLM + Ranger + Rangebag.

**Uncertainty Metrics**: When ensemble is used, the app outputs:
- Standard deviation across models
- Coefficient of variation
- 95% confidence intervals (lower/upper)
- Model agreement (% of models predicting above threshold)

Output files include `_ensemble_sd.tif`, `_ensemble_cv.tif`, `_ensemble_ci_lo.tif`, `_ensemble_ci_hi.tif`, and `_ensemble_agreement.tif`.

## Run The App

### Windows

Double-click:

```text
run_app_windows.bat
```

This single runner finds R, installs missing packages, checks default WorldClim layers, and launches the app.

### macOS/Linux/RStudio Terminal

```bash
Rscript launch_app.R
```

Open the printed URL, usually:

```text
http://127.0.0.1:3838
```

## Command-Line Pipeline

```bash
Rscript pipeline.R
```

The CLI runner uses `presence_data.csv` from the project root and default settings.

## Verification

Run a lightweight source test:

```bash
Rscript scripts/smoke_test.R
```

This checks that the refactored modules load and key public functions exist. It does not require real occurrence data or rasters.
