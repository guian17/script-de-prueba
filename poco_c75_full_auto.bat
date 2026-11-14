@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
title POCO C75 Unbrick — Full Auto
color 0A

:: ══════════════════════════════════════════════════════════════
:: AUTO-ELEVACION — relanza como admin si no tiene privilegios
:: ══════════════════════════════════════════════════════════════
net session >nul 2>&1
if !errorLevel! neq 0 (
    echo Solicitando permisos de administrador...
    powershell -Command "Start-Process cmd.exe -ArgumentList '/c \"%~f0\"' -Verb RunAs -Wait"
    exit /b
)

:: ══════════════════════════════════════════════════════════════
:: Rutas
:: ══════════════════════════════════════════════════════════════
set "BASE=%USERPROFILE%\Desktop\POCO_C75_Unbrick"
set "DL=%BASE%\downloads"
set "TOOLS=%BASE%\tools\SPFlashTool"
set "DRIVERSDIR=%BASE%\drivers\MTK_VCOM"
set "ROMDIR=%BASE%\ROM\extracted"
set "LOG=%BASE%\log.txt"
set "SPFT_ZIP=%DL%\spft_v5.zip"
set "MTK_ZIP=%DL%\mtk_vcom.zip"
set "SCATTER="
set "SPFT_EXE="

:: ══════════════════════════════════════════════════════════════
:: Crear carpetas
:: ══════════════════════════════════════════════════════════════
for %%d in ("%BASE%" "%DL%" "%TOOLS%" "%DRIVERSDIR%" "%ROMDIR%") do mkdir "%%~d" 2>nul
echo [%time%] Iniciado > "%LOG%"

echo.
echo  POCO C75 EEA Unbrick — Auto Setup
echo  Windows 10 LTSC 2022
echo  ─────────────────────────────────
echo.

:: ══════════════════════════════════════════════════════════════
:: PASO 1 — Deshabilitar firma de drivers
:: ══════════════════════════════════════════════════════════════
echo  [1/6] Configurando sistema...
bcdedit /set testsigning on >nul 2>&1
bcdedit /set nointegritychecks on >nul 2>&1
echo       Test signing: OK >> "%LOG%"

:: ══════════════════════════════════════════════════════════════
:: PASO 2 — Descargar SP Flash Tool v5
:: ══════════════════════════════════════════════════════════════
echo  [2/6] Descargando SP Flash Tool v5...
echo       Descargando SP Flash Tool... >> "%LOG%"

set "SPFT_OK=0"
set "URLS[0]=https://spflashtools.com/windows/sp-flash-tool-v5-2404"
set "URLS[1]=https://spflashtool.com/files/SP_Flash_Tool_v5.2404_Win.zip"
set "URLS[2]=https://miuirom.org/uploads/sp-flash-tool-v5-2228.zip"

for /l %%i in (0,1,2) do (
    if "!SPFT_OK!"=="0" (
        curl -L --silent --max-time 120 -o "%SPFT_ZIP%" "!URLS[%%i]!" 2>>"%LOG%"
        if exist "%SPFT_ZIP%" (
            for %%s in ("%SPFT_ZIP%") do if %%~zs GTR 102400 set "SPFT_OK=1"
        )
        if "!SPFT_OK!"=="0" del /f /q "%SPFT_ZIP%" >nul 2>&1
    )
)

if "!SPFT_OK!"=="1" (
    powershell -NoProfile -Command "Expand-Archive -Path '%SPFT_ZIP%' -DestinationPath '%TOOLS%' -Force" >nul 2>&1
    echo       SP Flash Tool: OK >> "%LOG%"
    echo       OK
) else (
    echo       FALLO - descarga manual requerida >> "%LOG%"
    echo       FALLO - ver instrucciones al final
)

:: Buscar EXE
for /r "%TOOLS%" %%f in (flash_tool.exe SP_Flash_Tool.exe FlashTool.exe) do (
    if "!SPFT_EXE!"=="" set "SPFT_EXE=%%f"
)

:: ══════════════════════════════════════════════════════════════
:: PASO 3 — Descargar e instalar drivers MTK VCOM
:: ══════════════════════════════════════════════════════════════
echo  [3/6] Descargando drivers MTK VCOM...
echo       Descargando drivers MTK... >> "%LOG%"

set "MTK_OK=0"
set "MURLS[0]=https://www.thecustomdroid.com/wp-content/uploads/2019/09/MediaTek_Preloader_USB_VCOM_Drivers_Setup_Signed.zip"
set "MURLS[1]=https://droidwin.com/wp-content/uploads/2020/04/MTK_ALL_USB_VCOM_DRIVERS.zip"
set "MURLS[2]=https://teamandroid.com/wp-content/uploads/2016/12/MT67xx_USB_VCOM_DRIVERS.zip"

for /l %%i in (0,1,2) do (
    if "!MTK_OK!"=="0" (
        curl -L --silent --max-time 120 -o "%MTK_ZIP%" "!MURLS[%%i]!" 2>>"%LOG%"
        if exist "%MTK_ZIP%" (
            for %%s in ("%MTK_ZIP%") do if %%~zs GTR 102400 set "MTK_OK=1"
        )
        if "!MTK_OK!"=="0" del /f /q "%MTK_ZIP%" >nul 2>&1
    )
)

if "!MTK_OK!"=="1" (
    powershell -NoProfile -Command "Expand-Archive -Path '%MTK_ZIP%' -DestinationPath '%DRIVERSDIR%' -Force" >nul 2>&1
    echo       Drivers extraidos: OK >> "%LOG%"
    echo       Descarga OK — instalando...

    :: Instalar via pnputil (silencioso, no requiere confirmacion)
    set "DRV_OK=0"
    for /r "%DRIVERSDIR%" %%f in (*.inf) do (
        pnputil /add-driver "%%f" /install >nul 2>&1
        if !errorLevel! equ 0 set "DRV_OK=1"
        echo       pnputil: %%f >> "%LOG%"
    )

    :: Fallback — instalador EXE silencioso
    for /r "%DRIVERSDIR%" %%f in (*.exe) do (
        if "!DRV_OK!"=="0" (
            "%%f" /S >nul 2>&1
            if !errorLevel! equ 0 set "DRV_OK=1"
        )
    )

    echo       Drivers instalados: OK >> "%LOG%"
    echo       OK
) else (
    echo       FALLO descarga drivers >> "%LOG%"
    echo       FALLO descarga drivers
)

:: ══════════════════════════════════════════════════════════════
:: PASO 4 — Buscar ROM EEA en todo el sistema
:: ══════════════════════════════════════════════════════════════
echo  [4/6] Buscando ROM EEA en el disco...
echo       Buscando ROM... >> "%LOG%"

set "ROM_SRC="
set "ROM_OK=0"

for /f "tokens=1" %%d in ('wmic logicaldisk get name 2^>nul ^| findstr /r "[A-Z]:"') do (
    if "!ROM_OK!"=="0" (
        for /r "%%d\" %%f in (*WGTEUXM*.zip *WGTEUXM*.tgz *lake_eea*.zip *lake_eea*.tgz) do (
            if "!ROM_OK!"=="0" (
                set "ROM_SRC=%%f"
                set "ROM_OK=1"
                echo       ROM encontrada: %%f >> "%LOG%"
            )
        )
    )
)

if "!ROM_OK!"=="1" (
    echo  [5/6] Extrayendo ROM ^(!ROM_SRC!^)...
    :: Intentar ZIP
    powershell -NoProfile -Command "Expand-Archive -Path '!ROM_SRC!' -DestinationPath '%ROMDIR%' -Force" >nul 2>&1
    :: Intentar TGZ si ZIP fallo
    if !errorLevel! neq 0 (
        tar -xzf "!ROM_SRC!" -C "%ROMDIR%\" >nul 2>&1
    )
    echo       ROM extraida >> "%LOG%"
    echo       OK
) else (
    echo  [5/6] ROM no encontrada automaticamente
    echo       ROM no encontrada — copia manualmente >> "%LOG%"
)

:: Buscar scatter file
for /r "%ROMDIR%" %%f in (*scatter*.txt *Scatter*.txt) do (
    if "!SCATTER!"=="" (
        set "SCATTER=%%f"
        echo       Scatter: %%f >> "%LOG%"
    )
)
:: Buscar tambien un nivel arriba (si no se extrajo en subdirectorio)
if "!SCATTER!"=="" (
    for /r "%BASE%\ROM" %%f in (*scatter*.txt) do (
        if "!SCATTER!"=="" set "SCATTER=%%f"
    )
)

:: ══════════════════════════════════════════════════════════════
:: PASO 6 — Acceso directo y script de flash de un clic
:: ══════════════════════════════════════════════════════════════
echo  [6/6] Configurando acceso directo...

if not "!SPFT_EXE!"=="" (
    powershell -NoProfile -Command "$WS=New-Object -ComObject WScript.Shell; $SC=$WS.CreateShortcut('%USERPROFILE%\Desktop\SP Flash Tool v5.lnk'); $SC.TargetPath='!SPFT_EXE!'; $SC.WorkingDirectory='%TOOLS%'; $SC.Description='SP Flash Tool v5 - POCO C75 Unbrick'; $SC.Save()" >nul 2>&1
    echo       Acceso directo creado >> "%LOG%"
    echo       OK
)

:: ══════════════════════════════════════════════════════════════
:: Resumen final
:: ══════════════════════════════════════════════════════════════
echo.
echo  ═══════════════════════════════════════════════════════
echo   LISTO
echo  ═══════════════════════════════════════════════════════
echo.

if not "!SPFT_EXE!"=="" (
    echo   [OK] SP Flash Tool v5   instalado
) else (
    echo   [!!] SP Flash Tool      DESCARGA MANUAL
    echo        https://spflashtools.com/windows/sp-flash-tool-v5-2404
)

if "!DRV_OK!"=="1" (
    echo   [OK] Drivers MTK VCOM  instalados
) else (
    echo   [!!] Drivers MTK VCOM  instalar manualmente desde:
    echo        %DRIVERSDIR%
)

if not "!SCATTER!"=="" (
    echo   [OK] Scatter file       encontrado
    echo        !SCATTER!
) else (
    echo   [!!] Scatter file       copia tu ROM a: %BASE%\ROM
)

echo.
echo   SIGUIENTE PASO — REINICIAR EL PC
echo.
echo   Despues del reinicio:
echo   1. Abrir "SP Flash Tool v5" desde el Desktop
echo   2. Scatter-loading ^> MT6768_Android_Scatter.txt
echo   3. Download Only ^> Download
echo   4. Telefono APAGADO ^> mantener Vol- ^> conectar USB
echo   5. Esperar barra verde completa
echo.
echo  ═══════════════════════════════════════════════════════
echo.

start "" "%BASE%"
echo [%time%] Completado >> "%LOG%"

timeout /t 15 /nobreak >nul
choice /c SN /t 15 /d S /m "Reiniciar ahora para activar drivers? [S=si / N=no, auto-S en 15s]"
if !errorLevel! equ 1 (
    echo Reiniciando en 5 segundos...
    shutdown /r /t 5 /c "POCO C75 Setup — activando drivers MTK VCOM"
)

endlocal
exit /b 0
