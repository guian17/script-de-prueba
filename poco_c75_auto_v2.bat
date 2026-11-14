@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
title POCO C75 Unbrick Setup
color 0A

:: ══════════════════════════════════════════════════════════════
:: AUTO-ELEVACION sin reinicio
:: ══════════════════════════════════════════════════════════════
net session >nul 2>&1
if !errorLevel! neq 0 (
    powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: ══════════════════════════════════════════════════════════════
:: Rutas
:: ══════════════════════════════════════════════════════════════
set "BASE=%USERPROFILE%\Desktop\POCO_C75_Unbrick"
set "DL=%BASE%\downloads"
set "TOOLS=%BASE%\tools\SPFlashTool"
set "DRIVERSDIR=%BASE%\drivers\MTK_VCOM"
set "ROMDIR=%BASE%\ROM"
set "LOG=%BASE%\log.txt"
set "SPFT_ZIP=%DL%\spft_v5.zip"
set "MTK_ZIP=%DL%\mtk_vcom.zip"
set "SCATTER="
set "SPFT_EXE="
set "SPFT_OK=0"
set "MTK_OK=0"
set "DRV_OK=0"
set "ROM_OK=0"

:: Crear carpetas
for %%d in ("%BASE%" "%DL%" "%TOOLS%" "%DRIVERSDIR%" "%ROMDIR%" "%ROMDIR%\extracted") do (
    if not exist "%%~d" mkdir "%%~d"
)
echo [%date% %time%] Iniciado > "%LOG%"

echo.
echo  POCO C75 EEA Unbrick Setup
echo  ──────────────────────────────────────────────
echo.

:: ══════════════════════════════════════════════════════════════
:: PASO 1 — Test signing SIN reinicio
:: ══════════════════════════════════════════════════════════════
echo  [1/5] Configurando firma de drivers...
bcdedit /set testsigning on >nul 2>&1
bcdedit /set nointegritychecks on >nul 2>&1
echo  [1/5] OK
echo [1] testsigning OK >> "%LOG%"

:: ══════════════════════════════════════════════════════════════
:: PASO 2 — SP Flash Tool v5
:: ══════════════════════════════════════════════════════════════
echo  [2/5] Descargando SP Flash Tool v5...
echo [2] Descargando SPFT >> "%LOG%"

:: Mirror 1
curl -L --silent --max-time 90 -o "%SPFT_ZIP%" "https://spflashtools.com/windows/sp-flash-tool-v5-2404" 2>>"%LOG%"
if exist "%SPFT_ZIP%" for %%s in ("%SPFT_ZIP%") do if %%~zs GTR 102400 set "SPFT_OK=1"
if "!SPFT_OK!"=="0" (
    del /f /q "%SPFT_ZIP%" >nul 2>&1
    :: Mirror 2
    curl -L --silent --max-time 90 -o "%SPFT_ZIP%" "https://spflashtool.com/files/SP_Flash_Tool_v5.2404_Win.zip" 2>>"%LOG%"
    if exist "%SPFT_ZIP%" for %%s in ("%SPFT_ZIP%") do if %%~zs GTR 102400 set "SPFT_OK=1"
)
if "!SPFT_OK!"=="0" (
    del /f /q "%SPFT_ZIP%" >nul 2>&1
    :: Mirror 3
    curl -L --silent --max-time 90 -o "%SPFT_ZIP%" "https://androidmtk.com/wp-content/uploads/2021/12/SP_Flash_Tool_v5.2228_Win.zip" 2>>"%LOG%"
    if exist "%SPFT_ZIP%" for %%s in ("%SPFT_ZIP%") do if %%~zs GTR 102400 set "SPFT_OK=1"
)

if "!SPFT_OK!"=="1" (
    powershell -NoProfile -Command "Expand-Archive -Path '%SPFT_ZIP%' -DestinationPath '%TOOLS%' -Force" >nul 2>&1
    echo  [2/5] SP Flash Tool OK
    echo [2] SPFT extraido OK >> "%LOG%"
) else (
    echo  [2/5] FALLO descarga SP Flash Tool
    echo [2] SPFT FALLO >> "%LOG%"
)

:: Buscar EXE de SP Flash Tool
for /r "%TOOLS%" %%f in (flash_tool.exe SP_Flash_Tool.exe FlashTool.exe) do (
    if "!SPFT_EXE!"=="" (
        set "SPFT_EXE=%%f"
        echo [2] SPFT EXE: %%f >> "%LOG%"
    )
)

:: ══════════════════════════════════════════════════════════════
:: PASO 3 — Drivers MTK VCOM
:: ══════════════════════════════════════════════════════════════
echo  [3/5] Descargando drivers MTK VCOM...
echo [3] Descargando drivers >> "%LOG%"

curl -L --silent --max-time 90 -o "%MTK_ZIP%" "https://www.thecustomdroid.com/wp-content/uploads/2019/09/MediaTek_Preloader_USB_VCOM_Drivers_Setup_Signed.zip" 2>>"%LOG%"
if exist "%MTK_ZIP%" for %%s in ("%MTK_ZIP%") do if %%~zs GTR 102400 set "MTK_OK=1"

if "!MTK_OK!"=="0" (
    del /f /q "%MTK_ZIP%" >nul 2>&1
    curl -L --silent --max-time 90 -o "%MTK_ZIP%" "https://droidwin.com/wp-content/uploads/2020/04/MTK_ALL_USB_VCOM_DRIVERS.zip" 2>>"%LOG%"
    if exist "%MTK_ZIP%" for %%s in ("%MTK_ZIP%") do if %%~zs GTR 102400 set "MTK_OK=1"
)

if "!MTK_OK!"=="1" (
    powershell -NoProfile -Command "Expand-Archive -Path '%MTK_ZIP%' -DestinationPath '%DRIVERSDIR%' -Force" >nul 2>&1
    echo [3] Drivers extraidos >> "%LOG%"

    :: Instalar cada .inf con pnputil
    for /r "%DRIVERSDIR%" %%f in (*.inf) do (
        echo [3] pnputil: %%f >> "%LOG%"
        pnputil /add-driver "%%f" /install >nul 2>&1
        if !errorLevel! equ 0 set "DRV_OK=1"
    )

    :: Fallback EXE
    if "!DRV_OK!"=="0" (
        for /r "%DRIVERSDIR%" %%f in (*install*.exe *setup*.exe *driver*.exe) do (
            if "!DRV_OK!"=="0" (
                "%%f" /S >nul 2>&1
                if !errorLevel! equ 0 set "DRV_OK=1"
            )
        )
    )

    if "!DRV_OK!"=="1" (
        echo  [3/5] Drivers MTK VCOM instalados OK
        echo [3] Drivers OK >> "%LOG%"
    ) else (
        echo  [3/5] Drivers extraidos - instalacion manual puede ser necesaria
        echo [3] Drivers requieren atencion >> "%LOG%"
    )
) else (
    echo  [3/5] FALLO descarga drivers
    echo [3] Drivers FALLO >> "%LOG%"
)

:: ══════════════════════════════════════════════════════════════
:: PASO 4 — Buscar ROM EEA en todo el disco
:: ══════════════════════════════════════════════════════════════
echo  [4/5] Buscando ROM EEA en el disco...
echo [4] Buscando ROM >> "%LOG%"

set "ROM_SRC="

for /f "tokens=1" %%d in ('wmic logicaldisk get name 2^>nul ^| findstr /r "[A-Z]:"') do (
    if "!ROM_OK!"=="0" (
        for /r "%%d\" %%f in (*WGTEUXM*.zip *WGTEUXM*.tgz *lake_eea*.zip *lake_eea*.tgz *C75*EEA*.zip) do (
            if "!ROM_OK!"=="0" (
                set "ROM_SRC=%%f"
                set "ROM_OK=1"
                echo [4] ROM: %%f >> "%LOG%"
            )
        )
    )
)

if "!ROM_OK!"=="1" (
    echo  [4/5] ROM encontrada: !ROM_SRC!
    echo  [4/5] Extrayendo ROM...

    :: Intentar ZIP primero
    powershell -NoProfile -Command "Expand-Archive -Path '!ROM_SRC!' -DestinationPath '%ROMDIR%\extracted' -Force" >nul 2>&1
    set "EXTRACT_OK=!errorLevel!"

    :: Si fallo, intentar TGZ con tar
    if "!EXTRACT_OK!" neq "0" (
        tar -xzf "!ROM_SRC!" -C "%ROMDIR%\extracted\" >nul 2>&1
    )
    echo  [4/5] ROM extraida OK
    echo [4] ROM extraida >> "%LOG%"
) else (
    echo  [4/5] ROM no encontrada automaticamente
    echo [4] ROM no encontrada >> "%LOG%"
)

:: Buscar scatter
for /r "%ROMDIR%" %%f in (*scatter*.txt *Scatter*.txt) do (
    if "!SCATTER!"=="" (
        set "SCATTER=%%f"
        echo [4] Scatter: %%f >> "%LOG%"
    )
)

:: ══════════════════════════════════════════════════════════════
:: PASO 5 — Acceso directo en Desktop
:: ══════════════════════════════════════════════════════════════
echo  [5/5] Creando acceso directo...

if not "!SPFT_EXE!"=="" (
    powershell -NoProfile -Command "$WS=New-Object -ComObject WScript.Shell; $SC=$WS.CreateShortcut('%USERPROFILE%\Desktop\SP Flash Tool v5.lnk'); $SC.TargetPath='!SPFT_EXE!'; $SC.WorkingDirectory='%TOOLS%'; $SC.Description='SP Flash Tool v5 - POCO C75'; $SC.Save()" >nul 2>&1
    echo  [5/5] Acceso directo creado en Desktop
    echo [5] Shortcut OK >> "%LOG%"
)

:: ══════════════════════════════════════════════════════════════
:: RESUMEN — sin reinicio automatico
:: ══════════════════════════════════════════════════════════════
echo.
echo  ══════════════════════════════════════════════════════
echo   RESUMEN
echo  ══════════════════════════════════════════════════════
echo.

if not "!SPFT_EXE!"=="" (
    echo   OK  SP Flash Tool v5 instalado
) else (
    echo   !!  SP Flash Tool FALLO
    echo       Descarga manual: spflashtools.com/windows/sp-flash-tool-v5-2404
)

if "!DRV_OK!"=="1" (
    echo   OK  Drivers MTK VCOM instalados
) else (
    echo   !!  Drivers MTK VCOM - revisar carpeta:
    echo       %DRIVERSDIR%
)

if not "!SCATTER!"=="" (
    echo   OK  Scatter file listo
    echo       !SCATTER!
) else if "!ROM_OK!"=="1" (
    echo   !!  ROM extraida pero scatter no encontrado
    echo       Busca MT6768_Android_Scatter.txt en: %ROMDIR%
) else (
    echo   !!  ROM no encontrada
    echo       Copia tu ZIP de ROM a: %ROMDIR%
    echo       Luego vuelve a ejecutar este script
)

echo.
echo  ══════════════════════════════════════════════════════
echo   SIGUIENTE PASO:
echo.
echo   1. Reiniciar el PC manualmente
echo   2. Abrir SP Flash Tool v5 desde el Desktop
echo   3. Scatter-loading ^> MT6768_Android_Scatter.txt
echo   4. Download Only ^> boton Download
echo   5. Telefono apagado ^> mantener Vol- ^> conectar USB
echo   6. Esperar barra verde
echo  ══════════════════════════════════════════════════════
echo.

start "" "%BASE%"
echo [%date% %time%] Completado >> "%LOG%"

echo  Presiona cualquier tecla para cerrar...
pause >nul
endlocal
