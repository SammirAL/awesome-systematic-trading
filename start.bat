@echo off
rem One-click launcher (Windows) for the Awesome Systematic Trading local app.
rem Zero dependencies: only needs Python 3 (https://www.python.org/downloads/).
setlocal
cd /d "%~dp0"

where py >nul 2>nul
if %errorlevel%==0 (
  py -3 local_app\server.py %*
  goto :end
)

where python >nul 2>nul
if %errorlevel%==0 (
  python local_app\server.py %*
  goto :end
)

where docker >nul 2>nul
if %errorlevel%==0 (
  echo Python 3 not found - starting with Docker instead...
  docker compose up --build
  goto :end
)

echo ----------------------------------------------------------------
echo   Python 3 (or Docker) is required to run this app.
echo   Python 3 (ou Docker) est requis pour lancer cette application.
echo   ^> https://www.python.org/downloads/
echo   (check "Add python.exe to PATH" during installation)
echo ----------------------------------------------------------------

:end
pause
