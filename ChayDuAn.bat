@echo off
setlocal EnableExtensions
chcp 65001 >nul
cd /d "%~dp0"
title Chay Du An - Tro ly Cuu ho AI

echo =======================================================================
echo   CHAY DU AN TRO LY CUU HO AI - SERPER GOOGLE MAPS - ZERO MEDGEMMA
echo =======================================================================
echo.

set "FLUTTER_EXE="
set "PY_CMD="
set "PY_DISPLAY="
set "STARTED_API=0"
set "TARGET_DEVICE=chrome"

call :detect_flutter
if not defined FLUTTER_EXE goto :missing_flutter
echo [+] Flutter SDK: "%FLUTTER_EXE%"

if exist ".dart_tool\package_config.json" goto :after_pub_get
echo [i] Lan chay dau tien - dang tai thu vien Flutter...
call "%FLUTTER_EXE%" pub get
if errorlevel 1 goto :pub_get_failed

:after_pub_get
call :detect_python
if defined PY_CMD goto :python_ready

echo [!] Khong tim thay Python 3 tren may - tu dong chon Windows App.
set "TARGET_DEVICE=windows"
goto :run_app

:python_ready
echo [+] Python API: %PY_DISPLAY%
echo.
echo Chon nen tang de chay:
echo   [1] Chrome Web ^(co GPS trinh duyet - mac dinh sau 4 giay^)
echo   [2] Windows Desktop App
echo.
choice /C 12 /N /T 4 /D 1 /M "Lua chon cua ban [1/2]: "
if errorlevel 2 set "TARGET_DEVICE=windows"

echo.
%PY_CMD% -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8765/api/status', timeout=0.6)" >nul 2>&1
if not errorlevel 1 (
    echo [+] Local API cong 8765 da san sang.
    goto :run_app
)

echo [+] Dang khoi dong Google Maps ^(Serper.dev^) va YOLO Local API cong 8765...
start "WebVinhNam-LocalAPI" /MIN %PY_CMD% -X utf8 -B "%~dp0backend\run_places_server.py" --port 8765
set "STARTED_API=1"
call :wait_local_api

:run_app
echo.
echo [i] Dang mo ung dung tren %TARGET_DEVICE%...
echo     Nhan phim 'q' tai cua so nay de dung ung dung va tat API nen.
echo.

if /I "%TARGET_DEVICE%"=="chrome" (
    set "FLUTTER_WINDOWS=false"
    call "%FLUTTER_EXE%" run -d chrome --dart-define=MEDGEMMA_API_BASE_URL=http://127.0.0.1:8765
) else (
    set "FLUTTER_WINDOWS=true"
    call "%FLUTTER_EXE%" run -d windows --dart-define=MEDGEMMA_API_BASE_URL=http://127.0.0.1:8765
)
set "RUN_EXIT=%ERRORLEVEL%"

:cleanup
if "%STARTED_API%"=="1" (
    echo.
    echo [i] Dang tat Local API nen...
    taskkill /FI "WINDOWTITLE eq WebVinhNam-LocalAPI*" /T /F >nul 2>&1
)

if not "%RUN_EXIT%"=="0" (
    echo.
    echo [!] Ung dung ket thuc voi ma loi %RUN_EXIT%.
    pause
)
exit /b %RUN_EXIT%

:missing_flutter
echo [X] Khong tim thay Flutter SDK tren may!
echo     Hay cai dat Flutter SDK hoac them thu muc flutter\bin vao PATH,
echo     hoac dat bien moi truong FLUTTER_ROOT roi thu lai.
echo.
pause
exit /b 1

:pub_get_failed
echo [X] flutter pub get that bai!
pause
exit /b 1

:wait_local_api
%PY_CMD% -c "import sys,time,urllib.request;exec('for _ in range(25):\n try:\n  urllib.request.urlopen(sys.argv[1],timeout=0.4);sys.exit(0)\n except Exception:\n  time.sleep(0.2)\nsys.exit(1)')" http://127.0.0.1:8765/api/status >nul 2>&1
if not errorlevel 1 (
    echo [+] Local API cong 8765 da san sang!
) else (
    echo [!] Local API khoi dong cham hon du kien, van tiep tuc mo app...
)
goto :eof

:detect_flutter
if defined FLUTTER_ROOT call :try_flutter_exe "%FLUTTER_ROOT%\bin\flutter.bat"
if not defined FLUTTER_EXE (
    for /f "delims=" %%I in ('where flutter.bat 2^>nul') do call :try_flutter_exe "%%I"
)
call :try_flutter_exe "D:\fluter\flutter\bin\flutter.bat"
call :try_flutter_exe "D:\IT\FlutterInstall\flutter\bin\flutter.bat"
call :try_flutter_exe "C:\src\flutter\bin\flutter.bat"
call :try_flutter_exe "C:\flutter\bin\flutter.bat"
call :try_flutter_exe "D:\flutter\bin\flutter.bat"
call :try_flutter_exe "D:\src\flutter\bin\flutter.bat"
call :try_flutter_exe "C:\tools\flutter\bin\flutter.bat"
call :try_flutter_exe "%USERPROFILE%\flutter\bin\flutter.bat"
call :try_flutter_exe "%USERPROFILE%\fvm\default\bin\flutter.bat"
call :try_flutter_exe "%LOCALAPPDATA%\flutter\bin\flutter.bat"
goto :eof

:try_flutter_exe
if defined FLUTTER_EXE goto :eof
if "%~1"=="" goto :eof
if not exist "%~1" goto :eof
set "FLUTTER_EXE=%~1"
goto :eof

:detect_python
call :try_python_exe "%~dp0.venv\Scripts\python.exe"
call :try_python_cmd "python"
call :try_python_cmd "py -3"
call :try_python_exe "%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
call :try_python_exe "%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
call :try_python_exe "%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
call :try_python_exe "%LOCALAPPDATA%\Programs\Python\Python310\python.exe"
call :try_python_exe "C:\Python313\python.exe"
call :try_python_exe "C:\Python312\python.exe"
call :try_python_exe "C:\Python311\python.exe"
call :try_python_exe "C:\Python310\python.exe"
goto :eof

:try_python_exe
if defined PY_CMD goto :eof
if "%~1"=="" goto :eof
if not exist "%~1" goto :eof
"%~1" -c "import sys" >nul 2>&1
if errorlevel 1 goto :eof
set "PY_CMD="%~1""
set "PY_DISPLAY=%~1"
goto :eof

:try_python_cmd
if defined PY_CMD goto :eof
%~1 -c "import sys" >nul 2>&1
if errorlevel 1 goto :eof
set "PY_CMD=%~1"
set "PY_DISPLAY=%~1"
goto :eof
