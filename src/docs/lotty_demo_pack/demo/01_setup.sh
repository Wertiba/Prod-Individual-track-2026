#!/usr/bin/env bash
# 01_setup.sh — Инициализация: логин, пользователи, аппрувер-группы, каталоги
# Покрывает: B1-5 (happy-path), B3-5 (роли), B9-1/B9-2

source "$(dirname "$0")/env.sh"
> "$STATE_FILE"   # сбрасываем state

section "01 SETUP — Инициализация системы"

# ─────────────────────────────────────────────────────────────
step "1.1 Health & Readiness (B9)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 200 от /health"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API/health")
check_status "$STATUS" 200 "/health"

expect "HTTP 200 от /ready (БД доступна)"
RESP=$(curl -s -w "\n%{http_code}" "$API/ready")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 200 "/ready"
pretty "$BODY"

# ─────────────────────────────────────────────────────────────
step "1.2 Логин Admin"
# ─────────────────────────────────────────────────────────────
expect "HTTP 200, accessToken в ответе"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/auth/login" \
  -H "Content-Type: application/json" \
  -c /tmp/lotty_cookies_admin.txt \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 200 "login admin"
pretty "$BODY"

ADMIN_TOKEN=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('accessToken',''))")
save_state "ADMIN_TOKEN" "$ADMIN_TOKEN"
echo "  Admin token: ${ADMIN_TOKEN:0:40}..."

# ─────────────────────────────────────────────────────────────
step "1.3 Создание пользователя-Experimenter"
# ─────────────────────────────────────────────────────────────
expect "HTTP 201, новый пользователь с ролью EXPR"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/users" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "email": "experimenter@lotty.ru",
    "password": "exp12345",
    "fullName": "Ivan Experimenter",
    "roles": ["EXPR"],
    "required": 1
  }')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 201 "create experimenter"
pretty "$BODY"

EXPR_ID=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))")
save_state "EXPR_ID" "$EXPR_ID"
echo "  Experimenter ID: $EXPR_ID"

# ─────────────────────────────────────────────────────────────
step "1.4 Создание пользователя-Approver"
# ─────────────────────────────────────────────────────────────
expect "HTTP 201, новый пользователь с ролью APPR"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/users" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "email": "approver@lotty.ru",
    "password": "appr12345",
    "fullName": "Maria Approver",
    "roles": ["APPR"],
    "required": 0
  }')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 201 "create approver"

APPR_ID=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))")
save_state "APPR_ID" "$APPR_ID"
echo "  Approver ID: $APPR_ID"

# ─────────────────────────────────────────────────────────────
step "1.5 Создание пользователя-Viewer"
# ─────────────────────────────────────────────────────────────
expect "HTTP 201, новый пользователь с ролью VIEW"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/users" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "email": "viewer@lotty.ru",
    "password": "view12345",
    "fullName": "Petr Viewer",
    "roles": ["VIEW"],
    "required": 0
  }')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 201 "create viewer"

VIEWER_ID=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))")
save_state "VIEWER_ID" "$VIEWER_ID"
echo "  Viewer ID: $VIEWER_ID"

# ─────────────────────────────────────────────────────────────
step "1.6 Создание нескольких тестовых пользователей-участников экспериментов"
# ─────────────────────────────────────────────────────────────
expect "HTTP 201 для каждого из 5 пользователей"
for i in 1 2 3 4 5; do
  RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/users" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -d "{
      \"email\": \"user${i}@lotty.ru\",
      \"password\": \"user${i}pass\",
      \"fullName\": \"Test User $i\",
      \"roles\": [\"VIEW\"],
      \"required\": 0
    }")
  STATUS=$(echo "$RESP" | tail -1)
  BODY=$(echo "$RESP" | head -1)
  UID=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))")
  save_state "USER${i}_ID" "$UID"
  check_status "$STATUS" 201 "user$i"
  echo "  User$i ID: $UID"
done

# ─────────────────────────────────────────────────────────────
step "1.7 Назначение аппрувер-группы для Experimenter (Admin → Approver)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 200, аппрувер назначен"
load_state
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/users/approvers" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d "{
    \"experimenter_id\": \"$EXPR_ID\",
    \"approver_id\": \"$APPR_ID\"
  }")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 200 "assign approver"
pretty "$BODY"

APPR_LINK_ID=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))")
save_state "APPR_LINK_ID" "$APPR_LINK_ID"

# ─────────────────────────────────────────────────────────────
step "1.8 Логин Experimenter"
# ─────────────────────────────────────────────────────────────
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/auth/login" \
  -H "Content-Type: application/json" \
  -c /tmp/lotty_cookies_expr.txt \
  -d '{"email":"experimenter@lotty.ru","password":"exp12345"}')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 200 "login experimenter"

EXPR_TOKEN=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('accessToken',''))")
save_state "EXPR_TOKEN" "$EXPR_TOKEN"
echo "  Experimenter token: ${EXPR_TOKEN:0:40}..."

# ─────────────────────────────────────────────────────────────
step "1.9 Логин Approver"
# ─────────────────────────────────────────────────────────────
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/auth/login" \
  -H "Content-Type: application/json" \
  -c /tmp/lotty_cookies_appr.txt \
  -d '{"email":"approver@lotty.ru","password":"appr12345"}')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 200 "login approver"

APPR_TOKEN=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('accessToken',''))")
save_state "APPR_TOKEN" "$APPR_TOKEN"

# ─────────────────────────────────────────────────────────────
step "1.10 Проверка каталога метрик (базовые системные метрики)"
# ─────────────────────────────────────────────────────────────
expect "IMPRESSIONS, CONVERSIONS, CONVERSION_RATE, ERRORS, ERROR_RATE, AVG_LATENCY, P95_LATENCY"
RESP=$(curl -s -w "\n%{http_code}" "$API/metric-catalog?limit=20" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 200 "metric catalog"
echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); [print('  -', m['code']) for m in d.get('items',[])]"

# ─────────────────────────────────────────────────────────────
step "1.11 Проверка каталога событий (базовые системные события)"
# ─────────────────────────────────────────────────────────────
expect "EXPOSURE, CONVERSION, ERROR, LATENCY, CLICK, PURCHASE"
RESP=$(curl -s -w "\n%{http_code}" "$API/event-catalog?limit=20" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 200 "event catalog"
echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); [print('  -', m['code'], '| requiresExposure:', m['requiresExposure']) for m in d.get('items',[])]"

# ─────────────────────────────────────────────────────────────
step "1.12 Привязка событий к метрикам (EventMetricLink)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 201 для каждой привязки"

# IMPRESSIONS ← EXPOSURE
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/metric-catalog/assign" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "metricCatalog_code": "IMPRESSIONS",
    "items": [{"eventCatalog_code": "EXPOSURE", "role": "numerator"}]
  }')
STATUS=$(echo "$RESP" | tail -1)
check_status "$STATUS" 201 "link EXPOSURE→IMPRESSIONS"

# CONVERSIONS ← CONVERSION
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/metric-catalog/assign" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "metricCatalog_code": "CONVERSIONS",
    "items": [{"eventCatalog_code": "CONVERSION", "role": "numerator"}]
  }')
STATUS=$(echo "$RESP" | tail -1)
check_status "$STATUS" 201 "link CONVERSION→CONVERSIONS"

# CONVERSION_RATE ← CONVERSION (числитель) + EXPOSURE (знаменатель)
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/metric-catalog/assign" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "metricCatalog_code": "CONVERSION_RATE",
    "items": [
      {"eventCatalog_code": "CONVERSION", "role": "numerator"},
      {"eventCatalog_code": "EXPOSURE", "role": "denominator"}
    ]
  }')
STATUS=$(echo "$RESP" | tail -1)
check_status "$STATUS" 201 "link CONVERSION_RATE"

# ERRORS ← ERROR
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/metric-catalog/assign" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "metricCatalog_code": "ERRORS",
    "items": [{"eventCatalog_code": "ERROR", "role": "numerator"}]
  }')
STATUS=$(echo "$RESP" | tail -1)
check_status "$STATUS" 201 "link ERROR→ERRORS"

# ERROR_RATE ← ERROR (числитель) + EXPOSURE (знаменатель)
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/metric-catalog/assign" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "metricCatalog_code": "ERROR_RATE",
    "items": [
      {"eventCatalog_code": "ERROR", "role": "numerator"},
      {"eventCatalog_code": "EXPOSURE", "role": "denominator"}
    ]
  }')
STATUS=$(echo "$RESP" | tail -1)
check_status "$STATUS" 201 "link ERROR_RATE"

# AVG_LATENCY ← LATENCY (value_field: value_ms)
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/metric-catalog/assign" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "metricCatalog_code": "AVG_LATENCY",
    "items": [{"eventCatalog_code": "LATENCY", "role": "numerator", "value_field": "value_ms"}]
  }')
STATUS=$(echo "$RESP" | tail -1)
check_status "$STATUS" 201 "link LATENCY→AVG_LATENCY"

section "01 SETUP — ЗАВЕРШЕНО"
echo "State сохранён в $STATE_FILE"
cat "$STATE_FILE"
