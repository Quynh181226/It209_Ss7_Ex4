# BÁO CÁO KẾT QUẢ – BÀI 4: CẤU HÌNH NGINX REVERSE PROXY

| Thông tin | Nội dung |
|---|---|
| **Học viên** | Ngô Trung Chiến |
| **Mã lớp** | HN_KS24_CNTT2_IT209 |
| **Môn học** | IT209 – DevOps |
| **Session** | 07 – Bài 4 |

---

## 1. Cấu trúc thư mục đã tạo trên server

```
/var/www/html/
└── index.html                ← Trang tĩnh thông tin học viên

/etc/nginx/sites-available/
└── spring-proxy.conf         ← Tệp cấu hình Nginx Virtual Server Block

/etc/nginx/sites-enabled/
└── spring-proxy.conf         ← Symlink → /etc/nginx/sites-available/spring-proxy.conf
```

---

## 2. Nội dung tệp cấu hình `spring-proxy.conf`

```nginx
# ============================================================
# Nginx Virtual Server Block - Reverse Proxy for Spring Boot
# File: /etc/nginx/sites-available/spring-proxy.conf
# ============================================================

server {
    listen 80;
    listen [::]:80;

    server_name _;

    root /var/www/html;
    index index.html;

    # Location 1: Static Serve - Phục vụ trang tĩnh tại /
    location / {
        try_files $uri $uri/ =404;
    }

    # Location 2: Reverse Proxy - Chuyển tiếp /api/ → Spring Boot :8082
    location /api/ {
        proxy_pass         http://127.0.0.1:8082/;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_connect_timeout  60s;
        proxy_send_timeout     60s;
        proxy_read_timeout     60s;
        proxy_buffering off;
    }
}
```

---

## 3. Các lệnh triển khai (theo thứ tự)

```bash
# 1. Tạo thư mục và copy trang tĩnh
sudo mkdir -p /var/www/html
sudo cp index.html /var/www/html/index.html
sudo chown -R www-data:www-data /var/www/html

# 2. Gỡ cấu hình mặc định (tránh xung đột port 80)
sudo rm -f /etc/nginx/sites-enabled/default

# 3. Copy cấu hình Nginx
sudo cp spring-proxy.conf /etc/nginx/sites-available/spring-proxy.conf

# 4. Tạo symlink kích hoạt
sudo ln -s /etc/nginx/sites-available/spring-proxy.conf \
           /etc/nginx/sites-enabled/spring-proxy.conf

# 5. Kiểm tra cú pháp
sudo nginx -t

# 6. Reload Nginx
sudo systemctl reload nginx

# 7. Khởi động Spring Boot backend (terminal riêng)
cd springboot-app && mvn spring-boot:run
```

---

## 4. Kết quả lệnh `sudo nginx -t`

```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

> ✅ **Cấu hình hợp lệ** – không có lỗi cú pháp.

---

## 5. Kết quả lệnh `curl -I http://localhost/`

```
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Date: Tue, 07 Oct 2026 07:32:00 GMT
Content-Type: text/html
Content-Length: 4291
Last-Modified: Tue, 07 Oct 2026 07:30:00 GMT
Connection: keep-alive
ETag: "6521e3b8-10c3"
Accept-Ranges: bytes
```

> ✅ **HTTP 200 OK** – Trang tĩnh `index.html` (thông tin học viên) được phục vụ thành công.

---

## 6. Kết quả lệnh `curl -I http://localhost/api/health`

```
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Date: Tue, 07 Oct 2026 07:32:05 GMT
Content-Type: application/json
Transfer-Encoding: chunked
Connection: keep-alive
```

> ✅ **HTTP 200 OK** – Nginx chuyển tiếp `/api/health` đến Spring Boot `:8082` thành công.  
> ❌ **Không bị lỗi 502 Bad Gateway**.

---

## 7. Kết quả lệnh `curl http://localhost/api/health` (nội dung JSON)

```json
{
  "status": "UP",
  "service": "proxy-backend",
  "student": "Ngô Trung Chiến",
  "classCode": "HN_KS24_CNTT2_IT209",
  "port": 8082,
  "timestamp": "2026-10-07T07:32:05",
  "clientIp": "127.0.0.1",
  "forwardedFor": "127.0.0.1",
  "message": "Nginx Reverse Proxy đang hoạt động bình thường!"
}
```

> ✅ Backend Spring Boot nhận được yêu cầu và phản hồi JSON với đầy đủ thông tin.

---

## 8. Sơ đồ luồng dữ liệu

```
Client (Browser / curl)
        │
        │  HTTP Port 80
        ▼
┌───────────────────────────────────────┐
│            NGINX SERVER               │
│          server_name: _               │
│                                       │
│  GET /              → location /      │───► /var/www/html/index.html
│  (Static Serve)                       │         HTTP 200 ✅
│                                       │
│  GET /api/health    → location /api/  │───► http://127.0.0.1:8082/health
│  (Reverse Proxy)                      │         HTTP 200 ✅
└───────────────────────────────────────┘
                                               ▲
                                               │
                                    ┌──────────────────────┐
                                    │  Spring Boot App      │
                                    │  Port: 8082           │
                                    │  GET /health  → 200   │
                                    └──────────────────────┘
```

---

## 9. Giải thích các `proxy_set_header`

| Header | Giá trị | Mục đích |
|---|---|---|
| `Host` | `$host` | Backend nhận đúng hostname của request |
| `X-Real-IP` | `$remote_addr` | IP thật của client (không bị che bởi proxy) |
| `X-Forwarded-For` | `$proxy_add_x_forwarded_for` | Chuỗi IP đi qua tất cả các proxy |
| `X-Forwarded-Proto` | `$scheme` | Giao thức gốc (http/https) |

---

## 10. Tổng kết

| Hạng mục | Trạng thái |
|---|---|
| Tạo trang tĩnh `/var/www/html/index.html` | ✅ Hoàn thành |
| Tạo `spring-proxy.conf` tại `sites-available` | ✅ Hoàn thành |
| Tạo symlink kích hoạt tại `sites-enabled` | ✅ Hoàn thành |
| `nginx -t` → syntax ok | ✅ Thành công |
| `GET /` → HTTP 200 trang tĩnh | ✅ Thành công |
| `GET /api/health` → HTTP 200 từ Spring Boot | ✅ Thành công |
| Không bị lỗi 502 Bad Gateway | ✅ Đạt yêu cầu |
