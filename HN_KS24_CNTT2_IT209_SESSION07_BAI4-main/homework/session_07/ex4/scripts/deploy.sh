#!/bin/bash
# =============================================================
# deploy.sh – Script triển khai tự động Bài 4: Nginx Reverse Proxy
# Học viên : Ngô Trung Chiến | Mã lớp: HN_KS24_CNTT2_IT209
# Môn học  : IT209 – DevOps  | Session 07 – Bài 4
#
# Cách dùng:
#   chmod +x deploy.sh
#   sudo ./deploy.sh
# =============================================================

set -e  # Dừng ngay nếu có lỗi

# ---------- Màu sắc terminal ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ---------- Hàm tiện ích ----------
log_info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step()        { echo -e "\n${CYAN}══════════════════════════════════════${NC}"; \
                echo -e "${CYAN}  BƯỚC $1${NC}"; \
                echo -e "${CYAN}══════════════════════════════════════${NC}"; }

# ---------- Kiểm tra chạy với quyền root ----------
if [ "$EUID" -ne 0 ]; then
    log_error "Script phải chạy với quyền root (sudo ./deploy.sh)"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ═══════════════════════════════════════════════════
# BƯỚC 1: Cài đặt Nginx (nếu chưa có)
# ═══════════════════════════════════════════════════
step "1 – Kiểm tra & Cài đặt Nginx"

if ! command -v nginx &>/dev/null; then
    log_info "Nginx chưa được cài đặt. Tiến hành cài đặt..."
    apt-get update -qq
    apt-get install -y nginx
    log_success "Nginx đã được cài đặt thành công."
else
    NGINX_VER=$(nginx -v 2>&1 | grep -oP '[\d.]+')
    log_success "Nginx đã có sẵn: phiên bản $NGINX_VER"
fi

# ═══════════════════════════════════════════════════
# BƯỚC 2: Tạo thư mục và deploy trang tĩnh
# ═══════════════════════════════════════════════════
step "2 – Deploy trang tĩnh vào /var/www/html/"

mkdir -p /var/www/html
cp -f "$SCRIPT_DIR/../index.html" /var/www/html/index.html
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
log_success "Đã copy index.html → /var/www/html/index.html"

# ═══════════════════════════════════════════════════
# BƯỚC 3: Cài tệp cấu hình Nginx
# ═══════════════════════════════════════════════════
step "3 – Cài tệp cấu hình Nginx Virtual Server"

CONF_SRC="$SCRIPT_DIR/../spring-proxy.conf"
CONF_DEST="/etc/nginx/sites-available/spring-proxy.conf"
CONF_LINK="/etc/nginx/sites-enabled/spring-proxy.conf"

cp -f "$CONF_SRC" "$CONF_DEST"
log_success "Đã copy spring-proxy.conf → $CONF_DEST"

# ═══════════════════════════════════════════════════
# BƯỚC 4: Tạo symlink kích hoạt cấu hình
# ═══════════════════════════════════════════════════
step "4 – Kích hoạt cấu hình (symlink)"

# Xóa symlink cũ nếu có
if [ -L "$CONF_LINK" ]; then
    rm "$CONF_LINK"
    log_warn "Đã xóa symlink cũ: $CONF_LINK"
fi

ln -s "$CONF_DEST" "$CONF_LINK"
log_success "Đã tạo symlink: $CONF_LINK → $CONF_DEST"

# Gỡ cấu hình mặc định của Nginx để tránh xung đột cổng 80
if [ -L "/etc/nginx/sites-enabled/default" ]; then
    rm /etc/nginx/sites-enabled/default
    log_warn "Đã gỡ cấu hình mặc định Nginx (sites-enabled/default)"
fi

# ═══════════════════════════════════════════════════
# BƯỚC 5: Kiểm tra cú pháp Nginx
# ═══════════════════════════════════════════════════
step "5 – Kiểm tra cú pháp Nginx (nginx -t)"

echo ""
nginx -t
echo ""
log_success "Cú pháp Nginx hợp lệ!"

# ═══════════════════════════════════════════════════
# BƯỚC 6: Reload Nginx
# ═══════════════════════════════════════════════════
step "6 – Reload dịch vụ Nginx"

systemctl enable nginx
systemctl reload nginx
log_success "Nginx đã được reload thành công!"

# ═══════════════════════════════════════════════════
# BƯỚC 7: Kiểm tra trang tĩnh /
# ═══════════════════════════════════════════════════
step "7 – Kiểm tra phục vụ trang tĩnh (curl -I http://localhost/)"

echo ""
curl -s -I http://localhost/
echo ""

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/)
if [ "$HTTP_CODE" == "200" ]; then
    log_success "Trang tĩnh trả về HTTP $HTTP_CODE ✅"
else
    log_warn "Trang tĩnh trả về HTTP $HTTP_CODE (mong đợi 200)"
fi

# ═══════════════════════════════════════════════════
# BƯỚC 8: Kiểm tra Reverse Proxy /api/health
# ═══════════════════════════════════════════════════
step "8 – Kiểm tra Reverse Proxy (/api/health → Spring Boot :8082)"

echo ""
log_info "Đang kiểm tra Spring Boot có đang chạy tại cổng 8082..."

if curl -s --connect-timeout 3 http://127.0.0.1:8082/health > /dev/null 2>&1; then
    echo ""
    curl -s -I http://localhost/api/health
    echo ""
    API_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/api/health)
    if [ "$API_CODE" == "200" ]; then
        log_success "API /api/health trả về HTTP $API_CODE ✅ – Reverse Proxy hoạt động!"
    else
        log_warn "API /api/health trả về HTTP $API_CODE"
    fi
else
    log_warn "Spring Boot chưa chạy tại :8082."
    log_info "Hãy khởi động Spring Boot bằng lệnh:"
    echo -e "    ${YELLOW}cd springboot-app && mvn spring-boot:run${NC}"
    log_info "Sau đó chạy lại: curl -I http://localhost/api/health"
fi

# ═══════════════════════════════════════════════════
# HOÀN THÀNH
# ═══════════════════════════════════════════════════
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅  TRIỂN KHAI HOÀN TẤT THÀNH CÔNG!       ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║  Static  →  http://localhost/                ║${NC}"
echo -e "${GREEN}║  API     →  http://localhost/api/health      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
