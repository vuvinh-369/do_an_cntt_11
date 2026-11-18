# YOLOv8 Wound Detection Microservice

Microservice xử lý nhận diện tổn thương vết thương bằng mô hình YOLOv8 (`best.pt`).

## 1. Cài đặt môi trường
```bash
pip install -r requirements.txt
```

## 2. Khởi chạy Server
```bash
python server.py --host 0.0.0.0 --port 8000
```

## 3. API Endpoints
- `GET /health`: Kiểm tra trạng thái hoạt động của server và model.
- `POST /predict`: Nhận diện vết thương từ ảnh truyền vào (multipart form / base64).
  - Classes nhận diện: Trầy xước (abrasion), Vết cắt/rách (cut/laceration), Bỏng (burn), Bầm tím (bruise).
