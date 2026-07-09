@echo off
setlocal
cd /d "%~dp0\.."
title Windows CleanSweep Toolkit

echo ============================================
echo  Windows CleanSweep Toolkit
echo ============================================
echo.
echo 1. Scan only
echo 2. Clean safe temp files older than 3 days
echo 3. Scan with developer caches
echo 4. Exit
echo.
set /p choice=Select option: 

if "%choice%"=="1" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0CleanSweep.ps1" -ScanOnly
  pause
  exit /b
)

if "%choice%"=="2" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0CleanSweep.ps1" -Clean -OlderThanDays 3
  pause
  exit /b
)

if "%choice%"=="3" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0CleanSweep.ps1" -ScanOnly -IncludeDeveloperCaches
  pause
  exit /b
)

exit /b
