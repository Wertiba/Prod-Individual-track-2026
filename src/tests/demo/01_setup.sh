#!/usr/bin/env bash
# 01_setup.sh — Инициализация: логин, пользователи, аппрувер-группы, каталоги
source "$(dirname "$0")/env.sh"
> "$STATE_FILE"
rm -f "$COOKIE_ADMIN" "$COOKIE_EXPR" "$COOKIE_APPR" "$COOKIE_VIEW"

section "01 SETUP — Инициализация системы"

step "1.1 Health & Readiness"
expect "HTTP 200 от /health и /ready"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API/health")
check_status "$STATUS" 200 "/health"
RESP=$(curl -s -w "\n%{http_code}" "$API/ready")
check_status "$(echo "$RESP" | tail -1)" 200 "/ready"
pretty "$(echo "$RESP" | head -1)"

step "1.2 Логин Admin"
expect "HTTP 200, кука access_token сохранена"
RESP=$(curl -s -w "\n%{http_code}" -c "$COOKIE_ADMIN" -X POST "$API/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 200 "login admin"
echo "  Admin: $(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['user']['email'])")"

step "1.3 Создание Experimenter (required=1)"
expect "HTTP 201, роль EXPR"
# ВАЖНО: required=1 — нужен approver. Его назначим в шаге 1.7 ДО создания экспериментов
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_ADMIN" -X POST "$API/users" \
  -H "Content-Type: application/json" \
  -d '{"email":"experimenter@lotty.ru","password":"exp12345","fullName":"Ivan Experimenter","roles":["EXPR"],"required":1}')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 201 "create experimenter"
EXPR_ID=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))")
save_state "EXPR_ID" "$EXPR_ID"
echo "  Experimenter ID: $EXPR_ID"

step "1.4 Создание Approver"
expect "HTTP 201, роль APPR"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_ADMIN" -X POST "$API/users" \
  -H "Content-Type: application/json" \
  -d '{"email":"approver@lotty.ru","password":"appr12345","fullName":"Maria Approver","roles":["APPR"],"required":0}')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 201 "create approver"
APPR_ID=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))")
save_state "APPR_ID" "$APPR_ID"
echo "  Approver ID: $APPR_ID"

step "1.5 Создание Viewer"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_ADMIN" -X POST "$API/users" \
  -H "Content-Type: application/json" \
  -d '{"email":"viewer@lotty.ru","password":"view12345","fullName":"Petr Viewer","roles":["VIEW"],"required":0}')
check_status "$(echo "$RESP" | tail -1)" 201 "create viewer"
VIEWER_ID=$(echo "$RESP" | head -1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))")
save_state "VIEWER_ID" "$VIEWER_ID"

step "1.6 Создание 5 тестовых пользователей"
for i in 1 2 3 4 5; do
  RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_ADMIN" -X POST "$API/users" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"user${i}@lotty.ru\",\"password\":\"user${i}pass\",\"fullName\":\"Test User $i\",\"roles\":[\"VIEW\"],\"required\":0}")
  STATUS=$(echo "$RESP" | tail -1)
  UID=$(echo "$RESP" | head -1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))")
  save_state "USER${i}_ID" "$UID"
  check_status "$STATUS" 201 "user$i"
done

step "1.7 Назначение approver-группы (ВАЖНО: ДО создания экспериментов)"
expect "HTTP 200 — теперь Experimenter сможет создать эксперимент с required=1"
load_state
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_ADMIN" -X POST "$API/users/approvers" \
  -H "Content-Type: application/json" \
  -d "{\"experimenter_id\":\"$EXPR_ID\",\"approver_id\":\"$APPR_ID\"}")
check_status "$(echo "$RESP" | tail -1)" 200 "assign approver"
pretty "$(echo "$RESP" | head -1)"

step "1.8 Логин Experimenter"
curl -s -c "$COOKIE_EXPR" -X POST "$API/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"experimenter@lotty.ru","password":"exp12345"}' > /dev/null
echo "  ✅ Experimenter залогинен, кука: $COOKIE_EXPR"

step "1.9 Логин Approver"
curl -s -c "$COOKIE_APPR" -X POST "$API/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"approver@lotty.ru","password":"appr12345"}' > /dev/null
echo "  ✅ Approver залогинен, кука: $COOKIE_APPR"

step "1.10 Логин Viewer"
curl -s -c "$COOKIE_VIEW" -X POST "$API/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"viewer@lotty.ru","password":"view12345"}' > /dev/null
echo "  ✅ Viewer залогинен, кука: $COOKIE_VIEW"

step "1.11 Проверка каталога метрик"
expect "IMPRESSIONS, CONVERSIONS, CONVERSION_RATE, ERRORS, ERROR_RATE, AVG_LATENCY, P95_LATENCY"
RESP=$(curl -s -b "$COOKIE_ADMIN" "$API/metric-catalog?limit=20")
echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); [print('  -', m['code']) for m in d.get('items',[])]"

step "1.12 Проверка каталога событий"
expect "EXPOSURE, CONVERSION, ERROR, LATENCY, CLICK, PURCHASE"
RESP=$(curl -s -b "$COOKIE_ADMIN" "$API/event-catalog?limit=20")
echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); [print('  -', m['code']) for m in d.get('items',[])]"

step "1.13 Привязка событий к метрикам (EventMetricLink)"
for LINK in \
  '{"metricCatalog_code":"IMPRESSIONS","items":[{"eventCatalog_code":"EXPOSURE","role":"numerator"}]}' \
  '{"metricCatalog_code":"CONVERSIONS","items":[{"eventCatalog_code":"CONVERSION","role":"numerator"}]}' \
  '{"metricCatalog_code":"CONVERSION_RATE","items":[{"eventCatalog_code":"CONVERSION","role":"numerator"},{"eventCatalog_code":"EXPOSURE","role":"denominator"}]}' \
  '{"metricCatalog_code":"ERRORS","items":[{"eventCatalog_code":"ERROR","role":"numerator"}]}' \
  '{"metricCatalog_code":"ERROR_RATE","items":[{"eventCatalog_code":"ERROR","role":"numerator"},{"eventCatalog_code":"EXPOSURE","role":"denominator"}]}' \
  '{"metricCatalog_code":"AVG_LATENCY","items":[{"eventCatalog_code":"LATENCY","role":"numerator","value_field":"value_ms"}]}'; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" -b "$COOKIE_ADMIN" -X POST "$API/metric-catalog/assign" \
    -H "Content-Type: application/json" -d "$LINK")
  CODE=$(echo "$LINK" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['metricCatalog_code'])")
  check_status "$STATUS" 201 "link $CODE"
done

section "01 SETUP — ЗАВЕРШЕНО"
echo "State: $STATE_FILE"
