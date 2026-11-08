@echo off
setlocal
pushd "%~dp0.."
set "FS_TEST_PYTHON=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
if not exist "%FS_TEST_PYTHON%" (
    echo The bundled Python runtime was not found. Open this project in Codex to run the checks.
    if not "%~1"=="--no-pause" pause
    popd
    exit /b 1
)
echo Testing ForeverSuite without starting World of Warcraft...
"%FS_TEST_PYTHON%" "work\check_vendor.py"
set "FS_TEST_RESULT=%ERRORLEVEL%"
echo.
if "%FS_TEST_RESULT%"=="0" (
    echo All offline checks passed.
) else (
    echo Offline checks failed. Share the error above when reporting the issue.
)
echo Actual game rendering and secure hardware actions still need an in-game check.
if not "%~1"=="--no-pause" pause
popd
exit /b %FS_TEST_RESULT%
