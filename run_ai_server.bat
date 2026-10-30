@echo off
title Wound Detection AI Server (YOLOv8)
echo ===================================================
echo   KHOI DONG HE THONG AI NHAN DIEN VET THUONG
echo   Model: YOLOv8 (best.pt)
echo   Endpoint: http://127.0.0.1:8000/predict
echo ===================================================
echo.

cd /d "%~dp0lib\AI_Model"

REM Kiem tra xem da cai dat ultralytics chua
python -c "import ultralytics, fastapi, uvicorn" >nul 2>&1
if %errorlevel% neq 0 (
    echo [*] Dang cai dat cac thu vien can thiet: ultralytics, fastapi, uvicorn, python-multipart, pillow...
    pip install -r requirements.txt
    if %errorlevel% neq 0 (
        echo [!] Loi khi cai dat thu vien. Vui long kiem tra lai ket noi mang va Python!
        pause
        exit /b 1
    )
)

echo [*] Dang khoi chay AI Server...
python server.py

pause
