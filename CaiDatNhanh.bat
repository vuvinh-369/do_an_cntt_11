@echo off
setlocal EnableExtensions
chcp 65001 >nul
cd /d "%~dp0"
title Thiet lap Moi truong Du an - Tro ly Cuu ho AI

echo =======================================================================
echo   KHOI TAO DU AN TRO LY CUU HO AI - KHONG CAN MEDGEMMA
echo =======================================================================
echo.

set "FLUTTER_EXE="
set "PY_CMD="
set "PY_DISPLAY="

call :detect_flutter
if not defined FLUTTER_EXE goto :missing_flutter
echo [+] Da tim thay Flutter: "%FLUTTER_EXE%"
echo.

echo [1/3] Dang tai cac goi thu vien Flutter...
call "%FLUTTER_EXE%" pub get
if errorlevel 1 goto :pub_get_failed
echo [+] Tai thu vien Flutter thanh cong!
echo.

echo [2/3] Dang kiem tra Python tren may...
call :detect_python
if not defined PY_CMD goto :no_python

echo [+] Da tim thay Python: %PY_DISPLAY%
echo [3/3] Kiem tra thu vien YOLO cho mo hinh best.pt ^(tuy chon^)...
%PY_CMD% -c "import ultralytics, PIL" >nul 2>&1
if not errorlevel 1 (
    echo [+] Thu vien ultralytics va pillow da san sang!
    goto :done_success
)

echo     Dang cai ultralytics pillow ^(chi can cho phan tich anh vet thuong^)...
%PY_CMD% -m pip install --quiet ultralytics pillow
if errorlevel 1 (
    echo [!] Chua cai duoc ultralytics/pillow. Google Maps va giao dien van chay binh thuong.
) else (
    echo [+] Da chuan bi xong thu vien YOLO cho mo hinh best.pt!
)
goto :done_success

:no_python
echo [!] Chua tim thay Python 3.
echo     - App Windows ^(F5 hoac ChayDuAn.bat muc 2^) van chay binh thuong
echo       va tu ket noi Google Maps ^(Serper.dev^).
echo     - Neu muon chay Chrome Web co GPS, hay cai Python 3.10+ tu python.org
echo       ^(tick "Add Python to PATH"^) roi chay lai file nay.

:done_success
echo.
echo =======================================================================
echo   CHUC MUNG: DU AN DA SAN SANG!
echo   - Nhan dup "ChayDuAn.bat" de chay ngay Chrome Web hoac Windows App.
echo   - Hoac mo VS Code va nhan F5 de chay Windows App ngay lap tuc.
echo   ^(Khong can tai MedGemma, khong can cau hinh thu cong file .env^)
echo =======================================================================
echo.
pause
exit /b 0

:missing_flutter
echo [X] Khong tim thay Flutter SDK tren may!
echo     Hay cai dat Flutter SDK hoac them thu muc flutter\bin vao PATH,
echo     hoac dat bien moi truong FLUTTER_ROOT roi chay lai CaiDatNhanh.bat.
echo.
pause
exit /b 1

:pub_get_failed
echo [X] flutter pub get that bai. Kiem tra ket noi mang hoac Flutter SDK.
echo.
pause
exit /b 1

:detect_flutter
if defined FLUTTER_ROOT call :try_flutter_exe "%FLUTTER_ROOT%\bin\flutter.bat"
if not defined FLUTTER_EXE (
    for /f "delims=" %%I in ('where flutter.bat 2^>nul') do call :try_flutter_exe "%%I"
)
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
