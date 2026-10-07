# BÀI 4: CẤU HÌNH NGINX REVERSE PROXY CHO SPRING BOOT

> **Học viên:** Ngô Trung Chiến  
> **Mã lớp:** HN_KS24_CNTT2_IT209  
> **Môn học:** IT209 – DevOps | Session 07 – Bài 4

---

## 📁 Cấu trúc thư mục

```
ex4/
├── spring-proxy.conf              ← ⭐ Cấu hình Nginx Virtual Server Block
├── index.html                     ← ⭐ Trang tĩnh thông tin học viên (/var/www/html/)
├── REPORT.md                      ← ⭐ Báo cáo kết quả lệnh nginx -t và curl
├── scripts/
│   ├── deploy.sh                  ← Script tự động triển khai toàn bộ hệ thống
│   └── start-backend.sh           ← Script build & khởi động Spring Boot
└── springboot-app/                ← Ứng dụng Spring Boot backend (port 8082)
    ├── pom.xml
    └── src/main/
        ├── java/com/devops/proxy/
        │   ├── ProxyBackendApplication.java   ← Entry point
        │   └── HealthController.java          ← REST: /health, /info
        └── resources/
            └── application.properties         ← port=8082, actuator config
```

---

## 🎯 Mục tiêu bài học

| Mục tiêu | Mô tả |
|---|---|
| **Virtual Server Block** | Cấu hình Nginx Server Block cho domain/IP cụ thể |
| **Static Serve** | Phục vụ trang HTML tĩnh trực tiếp tại `location /` |
| **Reverse Proxy** | Chuyển tiếp `/api/*` đến Spring Boot `:8082` tại `location /api/` |
| **Symlink Activation** | Kích hoạt cấu hình qua `sites-enabled` |
| **Proxy Headers** | Truyền đúng thông tin client qua `proxy_set_header` |

---

## 🏗️ Kiến trúc hệ thống

```
┌─────────────────────────────────────────────────────────────┐
│                          Client                             │
│                    (Browser / curl)                         │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTP Port 80
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    NGINX SERVER                             │
│                   server_name: _                            │
│                                                             │
│   ┌─────────────────────┐   ┌─────────────────────────┐    │
│   │   location /        │   │   location /api/        │    │
│   │   (Static Serve)    │   │   (Reverse Proxy)       │    │
│   │                     │   │                         │    │
│   │  /var/www/html/     │   │  proxy_pass             │    │
│   │  index.html         │   │  http://127.0.0.1:8082/ │    │
│   └─────────────────────┘   └──────────┬──────────────┘    │
└──────────────────────────────────────  │ ───────────────────┘
                                         │ localhost:8082
                                         ▼
                          ┌──────────────────────────┐
                          │   SPRING BOOT BACKEND    │
                          │   Port: 8082             │
                          │   GET /health   → 200    │
                          │   GET /info     → 200    │
                          └──────────────────────────┘
```

---

## 🚀 Hướng dẫn triển khai

### Yêu cầu hệ thống

- Ubuntu/Debian Linux (khuyến nghị Ubuntu 20.04+)
- Nginx
- Java 17+
- Maven 3.6+

---

### Phương án 1 – Tự động (khuyến nghị)

```bash
# Clone / copy thư mục ex4 lên máy Linux

# Cấp quyền thực thi
chmod +x scripts/deploy.sh
chmod +x scripts/start-backend.sh

# Terminal 1: Khởi động Spring Boot backend
./scripts/start-backend.sh

# Terminal 2: Triển khai Nginx (cần sudo)
sudo ./scripts/deploy.sh
```

---

### Phương án 2 – Thủ công (từng bước)

#### Bước 1 – Deploy trang tĩnh

```bash
sudo mkdir -p /var/www/html
sudo cp index.html /var/www/html/index.html
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html
```

#### Bước 2 – Cài cấu hình Nginx

```bash
sudo cp spring-proxy.conf /etc/nginx/sites-available/spring-proxy.conf
```

#### Bước 3 – Kích hoạt bằng symlink

```bash
# Gỡ cấu hình mặc định (tránh xung đột port 80)
sudo rm -f /etc/nginx/sites-enabled/default

# Tạo symlink kích hoạt
sudo ln -s /etc/nginx/sites-available/spring-proxy.conf \
           /etc/nginx/sites-enabled/spring-proxy.conf
```

#### Bước 4 – Kiểm tra cú pháp

```bash
sudo nginx -t
```

Kết quả mong đợi:
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

#### Bước 5 – Reload Nginx

```bash
sudo systemctl reload nginx
```

#### Bước 6 – Khởi động Spring Boot

```bash
cd springboot-app
mvn spring-boot:run
```

---

## ✅ Kiểm tra kết quả

### Trang tĩnh `location /`

```bash
curl -I http://localhost/
```

Kết quả mong đợi:
```
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Content-Type: text/html
```

### Reverse Proxy `location /api/`

```bash
curl -I http://localhost/api/health
```

Kết quả mong đợi:
```
HTTP/1.1 200 OK
Content-Type: application/json
```

```bash
curl http://localhost/api/health
```

Kết quả JSON:
```json
{
  "status": "UP",
  "service": "proxy-backend",
  "student": "Ngô Trung Chiến",
  "classCode": "HN_KS24_CNTT2_IT209",
  "port": 8082,
  "timestamp": "2026-10-07T07:32:00",
  "clientIp": "127.0.0.1",
  "message": "Nginx Reverse Proxy đang hoạt động bình thường!"
}
```

---

## 📋 Giải thích cấu hình `spring-proxy.conf`

```nginx
server {
    listen 80;          # Port HTTP mặc định
    server_name _;      # Khớp mọi hostname / IP

    root /var/www/html; # Thư mục chứa file tĩnh
    index index.html;

    # ① Static Serve: Phục vụ file tĩnh
    location / {
        try_files $uri $uri/ =404;
    }

    # ② Reverse Proxy: Chuyển /api/* → Spring Boot :8082
    location /api/ {
        proxy_pass         http://127.0.0.1:8082/;

        proxy_set_header   Host              $host;         # Hostname gốc
        proxy_set_header   X-Real-IP         $remote_addr;  # IP thật client
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;

        proxy_connect_timeout 60s;
        proxy_read_timeout    60s;
        proxy_buffering off;
    }
}
```

### Lý do dùng `proxy_pass http://127.0.0.1:8082/` (có dấu `/` cuối)

| URL Client | `proxy_pass` | URL gửi đến Backend |
|---|---|---|
| `/api/health` | `http://127.0.0.1:8082/` | `/health` |
| `/api/info`   | `http://127.0.0.1:8082/` | `/info` |

> **Quy tắc:** Khi `proxy_pass` có URI suffix (`/`), Nginx sẽ **thay thế** phần `location /api/` bằng URI đó, loại bỏ tiền tố `/api/` khỏi URL gửi đi.

---

## 🔧 Xử lý sự cố

| Triệu chứng | Nguyên nhân | Giải pháp |
|---|---|---|
| `502 Bad Gateway` | Spring Boot chưa chạy | Khởi động `./scripts/start-backend.sh` |
| `403 Forbidden` | Sai quyền file | `sudo chown -R www-data:www-data /var/www/html` |
| `nginx -t` thất bại | Cú pháp sai | Kiểm tra lại `spring-proxy.conf` |
| Xung đột port 80 | `default` config còn | `sudo rm /etc/nginx/sites-enabled/default` |

---

*Ngô Trung Chiến – HN_KS24_CNTT2_IT209 – IT209 DevOps Session 07*
