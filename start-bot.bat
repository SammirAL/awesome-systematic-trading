@echo off
rem One-click launcher (Windows) for the paper-trading bot.
rem Live market data by default; run "start-bot.bat --demo" to try it offline.
setlocal
cd /d "%~dp0"

rem Auto-update: fast-forward to the latest version when possible
rem (offline-safe, never blocks the launch).
where git >nul 2>nul
if %errorlevel%==0 if exist ".git" (
  echo Checking for updates...
  git pull --ff-only >nul 2>nul
)

py -3 -V >nul 2>nul
if %errorlevel%==0 (
  py -3 trading_bot\bot.py %*
  goto :end
)

python -V >nul 2>nul
if %errorlevel%==0 (
  python trading_bot\bot.py %*
  goto :end
)

echo ----------------------------------------------------------------
echo   Python 3 is required to run the bot.
echo   Install it with:  winget install Python.Python.3.12
echo   or from https://www.python.org/downloads/
echo ----------------------------------------------------------------

:end
pause
