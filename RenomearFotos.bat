@echo off
setlocal enabledelayedexpansion

echo.
REM -- Data atual no formato YYYYMMDD (via PowerShell; wmic foi removido do Win11) --
for /f %%a in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd"') do set "currentDate=%%a"

echo Data atual: !currentDate!
echo.

:CONFIRM
set /p userDate=Digite a data atual no formato YYYYMMDD para confirmar a execucao (ex: 20260623): 

if "!userDate!"=="!currentDate!" (
    echo Data correta. Executando o script...
) else (
    echo Data incorreta. Operacao cancelada.
    pause
    exit /b 1
)

echo.
REM -- Prefixo ------------------------------------------------------------
echo Escolha o prefixo dos arquivos renomeados:
echo     .  =  DSC_    ^(padrao Nikon, sRGB^)
echo     ,  =  DSCF    ^(padrao Fujifilm^)
echo     ou digite um prefixo personalizado ^(ex: IMG_^)
echo.
echo OBS: voce NAO precisa digitar o "_" do AdobeRGB.
echo      Arquivos cujo nome original ja comeca com "_" ^(ex: _DSC_0007, a
echo      versao AdobeRGB gerada pelo Capture One^) mantem o "_" sozinhos
echo      no nome novo. Ex: _DSC_0007.jpg  -^>  _DSC_0042.jpg
echo.
set /p prefix=Prefixo: 

if "%prefix%"=="." set prefix=DSC_
if "%prefix%"=="," set prefix=DSCF

echo.
REM -- Numero inicial da contagem ----------------------------------------
:ASK_START
set "startNum="
set /p startNum=De qual numero comecar a contagem? (Enter ou 1 = 0001): 
if "!startNum!"=="" set "startNum=1"

REM Valida: aceita apenas digitos
echo !startNum!| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo    ^>^> Entrada invalida. Digite apenas numeros ^(ou Enter para 1^).
    echo.
    goto ASK_START
)

echo.

REM -- Caminho do script PowerShell (mesma pasta deste BAT) ---------------
set PS1Script="%~dp0Rename_PowershellScript_com_argumento.ps1"

if not exist %PS1Script% (
    echo ERRO: Script PowerShell nao encontrado:
    echo    %PS1Script%
    echo Verifique o drive, a pasta e o nome do arquivo.
    pause
    exit /b 1
)

REM Pasta onde o BAT esta
set "CurrentDir=%~dp0"
set "CurrentDir=%CurrentDir:~0,-1%"

powershell -NoProfile -ExecutionPolicy Bypass -File %PS1Script% -folder "%CurrentDir%" -prefix "%prefix%" -startNum !startNum!

pause
