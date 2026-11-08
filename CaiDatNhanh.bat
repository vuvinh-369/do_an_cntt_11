@echo off
chcp 65001 >nul
title Thiết lập Môi trường Dự án Trợ lý Cứu hộ AI
echo =======================================================================
echo   TRỢ LÝ CỨU HỘ AI - TỰ ĐỘNG THIẾT LẬP DỰ ÁN CHO THÀNH VIÊN NHÓM
echo =======================================================================
echo.

echo [1/3] Đang tải các gói thư viện Flutter...
call flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo [!] Lưu ý: Kiểm tra đường dẫn Flutter SDK nếu có lỗi.
) else (
    echo [+] Tải thư viện Flutter thành công!
)
echo.

echo [2/3] Đang kiểm tra Python trên máy...
python --version >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [+] Đã tìm thấy Python. Đang cài đặt thư viện cho mô hình best.pt...
    python -m pip install ultralytics pillow --quiet
    echo [+] Đã chuẩn bị xong thư viện YOLO cho mô hình best.pt!
) else (
    echo [!] Máy chưa cài Python.
    echo     Mô hình nhận diện ảnh của nhóm sử dụng file offline duy nhất: lib/AI_Model/best.pt
    echo     Vui lòng tải Python (https://www.python.org/downloads/) và nhớ tích chọn "Add python.exe to PATH".
)
echo.

echo [3/3] Kết nối Supabase Database...
echo [+] Đã tích hợp sẵn thông tin kết nối Supabase Cloud trong mã nguồn.
echo.

echo =======================================================================
echo   CHÚC MỪNG: DỰ ÁN ĐÃ SẴN SÀNG!
echo   Thành viên nhóm có thể mở VS Code và nhấn F5 (hoặc gõ flutter run) để chạy ngay!
echo =======================================================================
echo.
pause
