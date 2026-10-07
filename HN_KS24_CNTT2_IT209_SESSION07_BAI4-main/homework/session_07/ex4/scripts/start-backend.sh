#!/bin/bash
# =============================================================
# start-backend.sh – Khởi động Spring Boot backend tại cổng 8082
# Học viên : Ngô Trung Chiến | Mã lớp: HN_KS24_CNTT2_IT209
# =============================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/../springboot-app"

echo -e "${BLUE}[INFO]${NC} Kiểm tra Java..."
if ! command -v java &>/dev/null; then
    echo -e "${YELLOW}[WARN]${NC} Java chưa được cài đặt. Tiến hành cài Java 17..."
    sudo apt-get update -qq
    sudo apt-get install -y openjdk-17-jdk
fi
java -version

echo -e "${BLUE}[INFO]${NC} Kiểm tra Maven..."
if ! command -v mvn &>/dev/null; then
    echo -e "${YELLOW}[WARN]${NC} Maven chưa được cài đặt. Tiến hành cài Maven..."
    sudo apt-get install -y maven
fi
mvn -version

echo ""
echo -e "${BLUE}[INFO]${NC} Build Spring Boot application..."
cd "$APP_DIR"
mvn clean package -DskipTests -q

JAR_FILE=$(find target -name "*.jar" | head -1)
echo -e "${GREEN}[OK]${NC}    Build thành công: $JAR_FILE"

echo ""
echo -e "${BLUE}[INFO]${NC} Khởi động Spring Boot tại cổng 8082..."
echo -e "${YELLOW}       Nhấn Ctrl+C để dừng ứng dụng${NC}"
echo ""

java -jar "$JAR_FILE"
