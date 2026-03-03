@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

REM =====================================================
REM  NanoChat (global) + IMG 64x64  — SELF UPDATING BAT
REM  Auto-update source: GitHub RAW (version.txt + NanoChat.bat)
REM  Cloudflare URL source: GitHub RAW (tunnel_url.txt)
REM =====================================================

REM ====== CONFIG ======
set "APIKEY=Szalisek1237"
set "LIMIT=50"

REM --- GitHub RAW links (YOUR REPO) ---
set "REPO_RAW_VER=https://raw.githubusercontent.com/olas2012z/ChatterBatch/main/client/version.txt"
set "REPO_RAW_BAT=https://raw.githubusercontent.com/olas2012z/ChatterBatch/main/client/NanoChat.bat"
set "TUNNEL_RAW=https://raw.githubusercontent.com/olas2012z/ChatterBatch/main/tunnel_url.txt"

REM --- local cache files ---
set "LOCAL_VER_FILE=%~dp0version_local.txt"
set "URL_CACHE=%~dp0last_url.txt"

REM --- current local version (zmieniaj gdy robisz release) ---
set "LOCAL_VER=1.0.0"

if not exist "%LOCAL_VER_FILE%" (
  echo %LOCAL_VER%>"%LOCAL_VER_FILE%"
)

call :CHECK_UPDATE

goto :MAIN

REM =====================================================
REM  AUTO UPDATE
REM =====================================================
:CHECK_UPDATE
set "REMOTE_VER="
for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass ^
  "$v=''; try{$v=(Invoke-WebRequest -UseBasicParsing '%REPO_RAW_VER%' -TimeoutSec 6).Content.Trim()}catch{}; if($v){$v}"`) do (
  set "REMOTE_VER=%%A"
)

if "%REMOTE_VER%"=="" exit /b

set "LOCAL_VER_READ="
set /p LOCAL_VER_READ=<"%LOCAL_VER_FILE%"

if "%LOCAL_VER_READ%"=="%REMOTE_VER%" exit /b

echo.
echo ==========================================
echo   Aktualizacja: %LOCAL_VER_READ%  ->  %REMOTE_VER%
echo   Pobieram nowa wersje klienta...
echo ==========================================
echo.

set "TMP_NEW=%~dp0NanoChat_new.bat"

powershell -NoProfile -ExecutionPolicy Bypass ^
  "try{Invoke-WebRequest -UseBasicParsing '%REPO_RAW_BAT%' -OutFile '%TMP_NEW%' -TimeoutSec 12}catch{}" >nul 2>nul

if not exist "%TMP_NEW%" (
  echo BLAD: nie udalo sie pobrac nowej wersji.
  timeout /t 2 >nul
  exit /b
)

for %%S in ("%TMP_NEW%") do set "NEWSIZE=%%~zS"
if %NEWSIZE% LSS 800 (
  echo BLAD: pobrana wersja wyglada na uszkodzona (za mala).
  del /q "%TMP_NEW%" >nul 2>nul
  timeout /t 2 >nul
  exit /b
)

echo %REMOTE_VER%>"%LOCAL_VER_FILE%"

echo OK. Instaluję update i restartuję...
set "SELF=%~f0"
cmd /c copy /y "%TMP_NEW%" "%SELF%" ^>nul ^& del /q "%TMP_NEW%" ^>nul ^& start "" "%SELF%" ^& exit

exit /b

REM =====================================================
REM  MAIN
REM =====================================================
:MAIN
cls
echo ================================
echo   NanoChat (global) + IMG 64x64
echo ================================
echo.

set /p "GROUP=ID grupy (np. Szalis_1): "
set /p "NICK=Nick: "

:loop
cls

call :GET_BASE_URL
if "%BASE_URL%"=="" (
  echo BLAD: Brak BASE_URL (nie pobralem tunnel_url.txt i brak cache).
  echo Upewnij sie ze repo istnieje i masz net.
  echo.
  timeout /t 2 >nul
  goto loop
)

echo ===== OSTATNIE %LIMIT% WIADOMOSCI =====
echo Grupa: %GROUP%
echo BASE:  %BASE_URL%
echo =======================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass ^
  "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
  "$h=@{ 'X-API-KEY'='%APIKEY%' };" ^
  "try{ (Invoke-RestMethod '%BASE_URL%/last?group=%GROUP%&limit=%LIMIT%' -Headers $h -TimeoutSec 6).messages }catch{ 'BLAD: brak polaczenia / zly klucz API / serwer nie dziala.' }"

echo.
echo (w) wyslij  (r) odswiez  (u) wklej link->wyslij IMG  (o) pokaz IMG  (q) wyjdz
set /p "A=Akcja: "
if /i "%A%"=="q" exit /b
if /i "%A%"=="r" goto loop
if /i "%A%"=="w" goto send
if /i "%A%"=="u" goto upload
if /i "%A%"=="o" goto openimg
goto loop

:upload
echo.
set /p "IMGURL=Wklej link do obrazka (https://...jpg/png/webp/gif): "
if "%IMGURL%"=="" goto loop
set /p "CAT=Kategoria (mem/irl/mapa/art/inne) [inne]: "
if "%CAT%"=="" set "CAT=inne"

start "" "%BASE_URL%/uploader.html#key=%APIKEY%&group=%GROUP%&nick=%NICK%&cat=%CAT%&url=%IMGURL%&autosend=1"
goto loop

:openimg
echo.
set /p "IMGID=Podaj IMG ID (18 hex) z wiadomosci [IMG:ID|...]: "
if "%IMGID%"=="" goto loop
start "" "%BASE_URL%/viewer.html#key=%APIKEY%&id=%IMGID%"
goto loop

:send
echo.
set /p "MSG=Wiadomosc: "
if "%MSG%"=="" goto loop

powershell -NoProfile -ExecutionPolicy Bypass ^
  "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
  "$h=@{ 'X-API-KEY'='%APIKEY%'; 'Content-Type'='application/json; charset=utf-8' };" ^
  "$b=@{group='%GROUP%';nick='%NICK%';msg='%MSG%'}|ConvertTo-Json -Compress;" ^
  "try{Invoke-RestMethod -Method Post '%BASE_URL%/send' -Headers $h -Body $b -TimeoutSec 6|Out-Null}catch{}" >nul

goto loop

REM =====================================================
REM  GET_BASE_URL (GitHub RAW + cache fallback)
REM =====================================================
:GET_BASE_URL
set "BASE_URL="

REM 1) try fetch from GitHub
for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass ^
  "$u=''; try{$u=(Invoke-WebRequest -UseBasicParsing '%TUNNEL_RAW%' -TimeoutSec 6).Content.Trim()}catch{}; if($u){$u}"`) do (
  set "BASE_URL=%%A"
)

REM 2) if ok, cache it
if not "%BASE_URL%"=="" (
  echo %BASE_URL%>"%URL_CACHE%"
  exit /b
)

REM 3) fallback to cache
if exist "%URL_CACHE%" (
  set /p BASE_URL=<"%URL_CACHE%"
)

exit /b