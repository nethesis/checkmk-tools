@echo off
REM Build ISO CheckMK usando Docker Desktop
REM Windows Batch Script

echo ================================================
echo   CheckMK Installer - Build ISO con Docker     
echo ================================================
echo.

cd /d "%~dp0"

REM Verifica Docker
echo Verifica Docker Desktop...
docker version >nul 2>&1
if errorlevel 1 (
    echo [ERRORE] Docker Desktop non e' in esecuzione!
    echo Avvia Docker Desktop e riprova.
    pause
    exit /b 1
)
echo [OK] Docker Desktop attivo
echo.

REM Build immagine
echo Building immagine Docker...
docker build -t checkmk-iso-builder .
if errorlevel 1 (
    echo [ERRORE] Build immagine fallita
    pause
    exit /b 1
)
echo [OK] Immagine creata
echo.

REM Conferma
echo Questo processo richiedera':
echo   - Download Ubuntu 24.04.3 ISO (~3.1 GB)
echo   - Spazio disco: ~10 GB
echo   - Tempo: 10-20 minuti
echo.
set /p CONFIRM="Continuare? (S/N): "
if /i not "%CONFIRM%"=="S" (
    echo Operazione annullata.
    pause
    exit /b 0
)

echo.
echo Generazione ISO in corso...
echo.

REM Esegui build ISO
docker run --rm --privileged -v "%cd%:/build" checkmk-iso-builder bash -c "cd /build && ./make-iso.sh"

if errorlevel 1 (
    echo.
    echo [ERRORE] Generazione ISO fallita
    pause
    exit /b 1
)

echo.
echo ================================================
echo   ISO generata con successo!
echo ================================================
echo.
echo L'ISO si trova in: %cd%\iso-output\checkmk-installer-v1.0-amd64.iso
echo.
echo Per scrivere su USB, usa Rufus o Balena Etcher
pause
