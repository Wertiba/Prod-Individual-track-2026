#!/usr/bin/env bash
# 09_negative.sh — Негативные сценарии (B8-1: негативные тесты)
# Покрывает: B3-4 (недопустимые переходы), B3-5 (права), B4-1/B4-2 (валидация),
#            B2-1 (default без эксперимента), дублирование флага/эксперимента
#
# ВАЖНО: запускать ПОСЛЕ 08_complete.sh (exp_button_color в статусе ARCHIVED)

source "$(dirname "$0")/env.sh"
load_state

section "09 NEGATIVE TESTS"

# ─────────────────────────────────────────────────────────────
step "9.1 Создание флага с дублирующимся кодом"
# ─────────────────────────────────────────────────────────────
expect "HTTP 409 или 422 — flag с кодом button_color уже существует"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_ADMIN" -X POST "$API/flags" \
  -H "Content-Type: application/json" \
  -d '{"code":"button_color","default":"purple","type":"STRING"}')
STATUS=$(echo "$RESP" | tail -1)
echo "  HTTP $STATUS"
if [[ "$STATUS" -ge 400 ]]; then echo "  ✅ Дублирующийся код флага отклонён"
else echo "  ❌ Ожидался 4xx, получен $STATUS"; fi

# ─────────────────────────────────────────────────────────────
step "9.2 Создание флага пользователем без прав (Viewer)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 403 — только Admin может создавать флаги"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_VIEW" -X POST "$API/flags" \
  -H "Content-Type: application/json" \
  -d '{"code":"flag_by_viewer","default":"x","type":"STRING"}')
check_status "$(echo "$RESP" | tail -1)" 403 "viewer cannot create flag"

# ─────────────────────────────────────────────────────────────
step "9.3 Создание эксперимента с несуществующим flag_code"
# ─────────────────────────────────────────────────────────────
expect "HTTP 404 — флаг nonexistent_flag не существует"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_EXPR" -X POST "$API/experiments" \
  -H "Content-Type: application/json" \
  -d '{"code":"exp_bad_flag","flag_code":"nonexistent_flag","name":"Плохой флаг","description":"test","part":50,"version":1.0,
       "variants":[{"name":"ctrl","value":"x","weight":25,"isControl":true},{"name":"var","value":"y","weight":25,"isControl":false}],
       "metrics":[{"metricCatalog_code":"CONVERSIONS","role":"MAIN"}]}')
STATUS=$(echo "$RESP" | tail -1)
echo "  HTTP $STATUS"
if [[ "$STATUS" -ge 400 ]]; then echo "  ✅ Несуществующий флаг отклонён"
else echo "  ❌ Ожидался 4xx, получен $STATUS"; fi

# ─────────────────────────────────────────────────────────────
step "9.4 Создание эксперимента: сумма весов != part"
# ─────────────────────────────────────────────────────────────
expect "HTTP 422 — sum(weights)=40 != part=50"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_EXPR" -X POST "$API/experiments" \
  -H "Content-Type: application/json" \
  -d '{"code":"exp_bad_weights","flag_code":"button_color","name":"Плохие веса","description":"test","part":50,"version":1.0,
       "variants":[{"name":"ctrl","value":"green","weight":20,"isControl":true},{"name":"var","value":"blue","weight":20,"isControl":false}],
       "metrics":[{"metricCatalog_code":"CONVERSIONS","role":"MAIN"}]}')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 422 "weight sum mismatch"
echo "  Ошибка: $(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(str(d)[:200])" 2>/dev/null)"

# ─────────────────────────────────────────────────────────────
step "9.5 Создание эксперимента без контрольного варианта"
# ─────────────────────────────────────────────────────────────
expect "HTTP 422 — нет варианта с isControl=True"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_EXPR" -X POST "$API/experiments" \
  -H "Content-Type: application/json" \
  -d '{"code":"exp_no_control","flag_code":"button_color","name":"Нет контрольного","description":"test","part":50,"version":1.0,
       "variants":[{"name":"var1","value":"blue","weight":25,"isControl":false},{"name":"var2","value":"yellow","weight":25,"isControl":false}],
       "metrics":[{"metricCatalog_code":"CONVERSIONS","role":"MAIN"}]}')
check_status "$(echo "$RESP" | tail -1)" 422 "no control variant"

# ─────────────────────────────────────────────────────────────
step "9.6 Недопустимый переход статуса: ARCHIVED → RUNNING"
# ─────────────────────────────────────────────────────────────
expect "HTTP 4xx — нельзя запустить архивированный эксперимент"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_EXPR" -X POST "$API/experiments/status/running" \
  -H "Content-Type: application/json" \
  -d '{"code": "exp_button_color"}')
STATUS=$(echo "$RESP" | tail -1)
echo "  HTTP $STATUS (exp_button_color в статусе ARCHIVED)"
if [[ "$STATUS" -ge 400 ]]; then echo "  ✅ Переход ARCHIVED→RUNNING заблокирован"
else echo "  ❌ Ожидался 4xx, получен $STATUS"; fi

# ─────────────────────────────────────────────────────────────
step "9.7 Запрос без авторизации"
# ─────────────────────────────────────────────────────────────
expect "HTTP 401 — нет токена"
RESP=$(curl -s -w "\n%{http_code}" "$API/flags")
check_status "$(echo "$RESP" | tail -1)" 401 "no auth token"

# ─────────────────────────────────────────────────────────────
step "9.8 Невалидный JWT"
# ─────────────────────────────────────────────────────────────
expect "HTTP 401 — невалидный токен"
RESP=$(curl -s -w "\n%{http_code}" "$API/flags" \
  -H "Authorization: Bearer totally.invalid.token")
check_status "$(echo "$RESP" | tail -1)" 401 "invalid token"

# ─────────────────────────────────────────────────────────────
step "9.9 Отчёт по несуществующему эксперименту"
# ─────────────────────────────────────────────────────────────
expect "HTTP 404 — эксперимент не найден"
PAST="2026-01-01T00:00:00"
FUTURE="2026-12-31T00:00:00"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_ADMIN" \
  "$API/reports/exp_does_not_exist_xyz?time_from=${PAST}&time_to=${FUTURE}")
STATUS=$(echo "$RESP" | tail -1)
echo "  HTTP $STATUS"
if [[ "$STATUS" -ge 400 ]]; then echo "  ✅ Отчёт по несуществующему заблокирован"
else echo "  ❌ Ожидался 4xx, получен $STATUS"; fi

# ─────────────────────────────────────────────────────────────
step "9.10 Experimenter пытается создать пользователя (только Admin)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 403"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_EXPR" -X POST "$API/users" \
  -H "Content-Type: application/json" \
  -d '{"email":"hacker@evil.com","password":"hack1234","fullName":"Hacker","roles":["ADMN"],"required":0}')
check_status "$(echo "$RESP" | tail -1)" 403 "experimenter cannot create users"

# ─────────────────────────────────────────────────────────────
step "9.11 Попытка запустить DRAFT напрямую → ошибка"
# ─────────────────────────────────────────────────────────────
expect "HTTP 4xx — DRAFT нельзя запустить без ревью"
curl -s -b "$COOKIE_EXPR" -X POST "$API/experiments" \
  -H "Content-Type: application/json" \
  -d '{"code":"exp_draft_only","flag_code":"show_banner","name":"Черновик","description":"test","part":100,"version":1.0,
       "variants":[{"name":"ctrl","value":"false","weight":50,"isControl":true},{"name":"var","value":"true","weight":50,"isControl":false}],
       "metrics":[{"metricCatalog_code":"CONVERSIONS","role":"MAIN"}]}' > /dev/null
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_EXPR" -X POST "$API/experiments/status/running" \
  -H "Content-Type: application/json" -d '{"code":"exp_draft_only"}')
STATUS=$(echo "$RESP" | tail -1)
echo "  HTTP $STATUS"
if [[ "$STATUS" -ge 400 ]]; then echo "  ✅ Запуск DRAFT заблокирован"
else echo "  ❌ Ожидался 4xx, получен $STATUS"; fi

section "09 NEGATIVE — ЗАВЕРШЕНО. Все границы системы проверены"
