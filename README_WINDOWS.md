# Running The SDM Web Interface On Windows

`Rscript.exe` is included when you install normal R for Windows. It is not downloaded separately.

## One-Click Method

1. Install R for Windows: <https://cran.r-project.org/bin/windows/base/>
2. Extract the SDM zip file. Do not run it from inside the compressed zip viewer.
3. Open the extracted folder.
4. Double-click:

```text
run_app_windows.bat
```

The runner does all preparation and launch steps:

- Finds `Rscript.exe`.
- Installs missing R packages.
- Creates output/cache folders.
- Downloads default WorldClim layers if they are missing and internet is available.
- Starts the Shiny app.

If the browser does not open, go to:

```text
http://127.0.0.1:3838
```

## OpenTopography Elevation Key

Elevation is optional. If you want to use it often, set the API key once in PowerShell:

```powershell
[Environment]::SetEnvironmentVariable("OPENTOPOGRAPHY_API_KEY", "your_key_here", "User")
```

Close and reopen the terminal/app after setting it. You can also leave this unset and enter the key in the app when elevation is enabled.

## Running From PowerShell

Open PowerShell in the extracted project folder, then run:

```powershell
.\run_app_windows.bat
```

Or run R directly:

```powershell
Rscript launch_app.R
```

If `Rscript` is not in PATH, use the full path, for example:

```powershell
& "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" launch_app.R
```

Adjust `R-4.4.3` to the installed R version.

## If Port 3838 Is Busy

In PowerShell:

```powershell
$env:PORT = "3839"
.\run_app_windows.bat
```

Then open:

```text
http://127.0.0.1:3839
```

## Data Files

The app needs occurrence data. Either keep `presence_data.csv` in the project folder or upload a CSV/TSV in the app.

Optional soil covariates need a local HWSD v2 GeoTIFF, normally:

```text
covariates\hwsd_v2\HWSD_V2_SMU_selected.tif
```

If this file is missing and soil is enabled, the app logs a warning and continues without soil.

## Common Problems

### `Rscript.exe was not found`

Install R from CRAN, then run `run_app_windows.bat` again. If still not found, run with the full path to `Rscript.exe`.

### Browser Says It Cannot Connect

Wait 10-30 seconds and refresh. R packages may still be loading.

### Package Install Fails

Make sure there is internet access. On Windows, CRAN usually installs binary packages, so Rtools is usually not needed for this app.

### Windows Firewall Prompt

Allow access on private networks. The app runs locally on your computer.
