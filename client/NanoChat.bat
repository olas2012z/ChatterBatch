@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

REM ====== KONFIG ======
set "BASE_URL=http://127.0.0.1:3007"
set "LIMIT=40"

set "TOKEN="
set "NICK="
set "ROOM="
set "CAT=ogolny"

:START
cls
echo ================================
echo   NanoChat PRO (konto/znajomi)
echo ================================
echo 1) Zaloguj
echo 2) Zarejestruj
echo 3) Wyjdz
echo.
set /p "C=Wybor: "
if "%C%"=="1" goto LOGIN
if "%C%"=="2" goto REGISTER
if "%C%"=="3" exit /b
goto START

:REGISTER
cls
echo === REJESTRACJA ===
set /p "N=Nick (3-20 A-Z0-9_): "
set /p "P=Haslo (min 4 znaki): "
powershell -NoProfile -ExecutionPolicy Bypass ^
  "$b=@{nick='%N%';pass='%P%'}|ConvertTo-Json -Compress;" ^
  "try{Invoke-RestMethod -Method Post '%BASE_URL%/auth/register' -ContentType 'application/json' -Body $b -TimeoutSec 8}catch{$_|Out-String}" 
echo.
pause
goto START

:LOGIN
cls
echo === LOGOWANIE ===
set /p "N=Nick: "
set /p "P=Haslo: "
for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass ^
  "$b=@{nick='%N%';pass='%P%'}|ConvertTo-Json -Compress;" ^
  "try{(Invoke-RestMethod -Method Post '%BASE_URL%/auth/login' -ContentType 'application/json' -Body $b -TimeoutSec 8).token}catch{''}"`) do set "TOKEN=%%A"
if "%TOKEN%"=="" (
  echo BLAD logowania.
  pause
  goto START
)
set "NICK=%N%"
set "ROOM="
set "CAT=ogolny"
goto MENU

:MENU
cls
echo ================================
echo   ZALOGOWANY: %NICK%
echo   ROOM: %ROOM%
echo   KAT:  %CAT%
echo ================================
echo 1) Moje grupy
echo 2) Stworz grupe
echo 3) Dolacz do grupy
echo 4) Ustaw kategorie (w grupie)
echo 5) Znajomi (lista/zapros/akceptuj)
echo 6) PV (DM) z znajomym
echo 7) Chat (wejdz do aktualnego room)
echo 8) Wyloguj
echo.
set /p "C=Wybor: "
if "%C%"=="1" goto MYGROUPS
if "%C%"=="2" goto CREATE_GROUP
if "%C%"=="3" goto JOIN_GROUP
if "%C%"=="4" goto SET_CAT
if "%C%"=="5" goto FRIENDS
if "%C%"=="6" goto DM_OPEN
if "%C%"=="7" goto CHAT
if "%C%"=="8" goto LOGOUT
goto MENU

:AUTHHDR
REM helper: build auth header in powershell
exit /b

:MYGROUPS
cls
echo === MOJE GRUPY ===
powershell -NoProfile -ExecutionPolicy Bypass ^
  "$h=@{Authorization='Bearer %TOKEN%'};" ^
  "try{(Invoke-RestMethod '%BASE_URL%/groups/my' -Headers $h -TimeoutSec 8).groups|Format-Table -AutoSize}catch{'BLAD'}"
echo.
set /p "G=Wejdz do grupy (ID) lub ENTER: "
if "%G%"=="" goto MENU
set "ROOM=%G%"
set "CAT=ogolny"
goto MENU

:CREATE_GROUP
cls
echo === STWORZ GRUPE ===
set /p "G=ID grupy (np. Szalis_1): "
set /p "NM=Nazwa (ENTER = taka sama): "
if "%NM%"=="" set "NM=%G%"
set /p "PS=Haslo (ENTER brak): "
powershell -NoProfile -ExecutionPolicy Bypass ^
  "$h=@{Authorization='Bearer %TOKEN%';'Content-Type'='application/json'};" ^
  "$b=@{id='%G%';name='%NM%';pass='%PS%'}|ConvertTo-Json -Compress;" ^
  "try{Invoke-RestMethod -Method Post '%BASE_URL%/groups/create' -Headers $h -Body $b -TimeoutSec 8}catch{$_|Out-String}"
echo.
pause
goto MENU

:JOIN_GROUP
cls
echo === DOLACZ DO GRUPY ===
set /p "G=ID grupy: "
set /p "PS=Haslo (jesli jest): "
powershell -NoProfile -ExecutionPolicy Bypass ^
  "$h=@{Authorization='Bearer %TOKEN%';'Content-Type'='application/json'};" ^
  "$b=@{id='%G%';pass='%PS%'}|ConvertTo-Json -Compress;" ^
  "try{Invoke-RestMethod -Method Post '%BASE_URL%/groups/join' -Headers $h -Body $b -TimeoutSec 8}catch{$_|Out-String}"
echo.
set "ROOM=%G%"
set "CAT=ogolny"
pause
goto MENU

:SET_CAT
if "%ROOM%"=="" (
  echo Najpierw wybierz ROOM (grupa) w: Moje grupy / Dolacz
  pause
  goto MENU
)
if "%ROOM:~0,4%"=="dm__" (
  echo PV ma zawsze kategorie pv.
  pause
  goto MENU
)
cls
echo === USTAW KATEGORIE (KANAL) ===
echo Aktualna: %CAT%
set /p "CAT=Nowa kategoria (np. ogolny/ogloszenia): "
if "%CAT%"=="" set "CAT=ogolny"
goto MENU

:FRIENDS
cls
echo === ZNAJOMI ===
powershell -NoProfile -ExecutionPolicy Bypass ^
  "$h=@{Authorization='Bearer %TOKEN%'};" ^
  "try{Invoke-RestMethod '%BASE_URL%/friends/list' -Headers $h -TimeoutSec 8}catch{'BLAD'}"
echo.
echo a) Zapros znajomego
echo b) Akceptuj znajomego (wpisz nick)  [czyli /akceptznajomy]
echo c) Wroc
set /p "F=Wybor: "
if /i "%F%"=="a" goto FRIEND_REQ
if /i "%F%"=="b" goto FRIEND_ACC
goto MENU

:FRIEND_REQ
set /p "TO=Nick do zaproszenia: "
powershell -NoProfile -ExecutionPolicy Bypass ^
  "$h=@{Authorization='Bearer %TOKEN%';'Content-Type'='application/json'};" ^
  "$b=@{to='%TO%'}|ConvertTo-Json -Compress;" ^
  "try{Invoke-RestMethod -Method Post '%BASE_URL%/friends/request' -Headers $h -Body $b -TimeoutSec 8}catch{$_|Out-String}"
pause
goto FRIENDS

:FRIEND_ACC
set /p "FROM=Nick ktory cie zaprosil: "
powershell -NoProfile -ExecutionPolicy Bypass ^
  "$h=@{Authorization='Bearer %TOKEN%';'Content-Type'='application/json'};" ^
  "$b=@{from='%FROM%'}|ConvertTo-Json -Compress;" ^
  "try{Invoke-RestMethod -Method Post '%BASE_URL%/friends/accept' -Headers $h -Body $b -TimeoutSec 8}catch{$_|Out-String}"
pause
goto FRIENDS

:DM_OPEN
cls
echo === PV (DM) ===
set /p "TO=Nick znajomego: "
for /f "usebackq delims=" %%A in (`powershell -NoProfile -ExecutionPolicy Bypass ^
  "$h=@{Authorization='Bearer %TOKEN%';'Content-Type'='application/json'};" ^
  "$b=@{with='%TO%'}|ConvertTo-Json -Compress;" ^
  "try{(Invoke-RestMethod -Method Post '%BASE_URL%/dm/open' -Headers $h -Body $b -TimeoutSec 8).room}catch{''}"`) do set "ROOM=%%A"
if "%ROOM%"=="" (
  echo BLAD: nie jestescie znajomymi albo nie ma usera.
  pause
  goto MENU
)
set "CAT=pv"
goto MENU

:CHAT
if "%ROOM%"=="" (
  echo Najpierw wybierz ROOM (grupa lub DM).
  pause
  goto MENU
)

:CHATLOOP
cls
echo ===== CHAT =====
echo NICK: %NICK%
echo ROOM: %ROOM%
echo KAT : %CAT%
echo =================
echo.

powershell -NoProfile -ExecutionPolicy Bypass ^
  "$h=@{Authorization='Bearer %TOKEN%'};" ^
  "try{(Invoke-RestMethod '%BASE_URL%/last?room=%ROOM%&limit=%LIMIT%' -Headers $h -TimeoutSec 8).messages}catch{'BLAD'}"

echo.
echo (w) wyslij  (r) odswiez  (m) menu
set /p "A=Akcja: "
if /i "%A%"=="m" goto MENU
if /i "%A%"=="r" goto CHATLOOP
if /i "%A%"=="w" goto SEND
goto CHATLOOP

:SEND
set /p "MSG=>> "
if "%MSG%"=="" goto CHATLOOP
powershell -NoProfile -ExecutionPolicy Bypass ^
  "$h=@{Authorization='Bearer %TOKEN%';'Content-Type'='application/json; charset=utf-8'};" ^
  "$b=@{room='%ROOM%';cat='%CAT%';msg='%MSG%'}|ConvertTo-Json -Compress;" ^
  "try{Invoke-RestMethod -Method Post '%BASE_URL%/send' -Headers $h -Body $b -TimeoutSec 8|Out-Null}catch{}" >nul
goto CHATLOOP

:LOGOUT
powershell -NoProfile -ExecutionPolicy Bypass ^
  "$h=@{Authorization='Bearer %TOKEN%'};" ^
  "try{Invoke-RestMethod -Method Post '%BASE_URL%/auth/logout' -Headers $h -TimeoutSec 6|Out-Null}catch{}" >nul
set "TOKEN="
set "NICK="
set "ROOM="
set "CAT=ogolny"
goto START
