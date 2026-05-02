@echo off
setlocal EnableExtensions

REM Compatibility wrapper. Preparation is now built into run_app_windows.bat.

cd /d "%~dp0"

call "%~dp0run_app_windows.bat"
