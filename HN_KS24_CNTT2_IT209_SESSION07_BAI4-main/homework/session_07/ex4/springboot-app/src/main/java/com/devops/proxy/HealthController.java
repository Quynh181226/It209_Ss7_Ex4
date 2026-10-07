package com.devops.proxy;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * HealthController – Cung cấp endpoint /health cho kiểm tra Reverse Proxy.
 *
 * Lưu ý về định tuyến:
 *   - Nginx nhận yêu cầu tại /api/health
 *   - proxy_pass http://127.0.0.1:8082/  →  chuyển thành  /health
 *   - Controller lắng nghe tại  /health  (không có tiền tố /api/)
 */
@RestController
@RequestMapping("/")
public class HealthController {

    @GetMapping("health")
    public ResponseEntity<Map<String, Object>> health(
            @RequestHeader(value = "X-Real-IP",       required = false) String realIp,
            @RequestHeader(value = "X-Forwarded-For", required = false) String forwardedFor) {

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("status",      "UP");
        body.put("service",     "proxy-backend");
        body.put("student",     "Ngô Trung Chiến");
        body.put("classCode",   "HN_KS24_CNTT2_IT209");
        body.put("port",        8082);
        body.put("timestamp",   LocalDateTime.now()
                                    .format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
        body.put("clientIp",    realIp != null ? realIp : "N/A");
        body.put("forwardedFor", forwardedFor != null ? forwardedFor : "N/A");
        body.put("message",     "Nginx Reverse Proxy đang hoạt động bình thường!");

        return ResponseEntity.ok(body);
    }

    @GetMapping("info")
    public ResponseEntity<Map<String, Object>> info() {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("app",      "IT209 DevOps – Session 07 Bài 4");
        body.put("student",  "Ngô Trung Chiến");
        body.put("class",    "HN_KS24_CNTT2_IT209");
        body.put("desc",     "Spring Boot backend chạy sau Nginx Reverse Proxy tại cổng 8082");
        return ResponseEntity.ok(body);
    }
}
