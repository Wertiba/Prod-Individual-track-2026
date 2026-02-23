#!/usr/bin/env bash
# 03_experiment_lifecycle.sh — Полный жизненный цикл + ревью
# КЛЮЧЕВОЙ ПОРЯДОК: сначала назначить approver (01_setup.sh шаг 1.7),
#                   потом создавать эксперимент от experimenter с required=1
source "$(dirname "$0")/env.sh"
load_state

section "03 EXPERIMENT LIFECYCLE"

EXP_PAYLOAD='{
  "code":"exp_button_color",
  "flag_code":"button_color",
  "name":"Тест цвета кнопки Купить",
  "description":"Проверяем: синяя или зелёная кнопка даёт больше конверсий",
  "part":100,
  "version":1.0,
  "variants":[
    {"name":"control_green","value":"green","weight":50,"isControl":true},
    {"name":"variant_blue","value":"blue","weight":50,"isControl":false}
  ],
  "metrics":[
    {"metricCatalog_code":"CONVERSION_RATE","role":"MAIN"},
    {"metricCatalog_code":"ERROR_RATE","role":"GUARDRAIL","window":3600,"threshold":50,"action_code":"PAUSE"},
    {"metricCatalog_code":"CONVERSIONS","role":"ADDITIONAL"}
  ]
}'

step "3.1 Создание эксперимента DRAFT (от Experimenter)"
expect "HTTP 201, status=DRAFT, 2 варианта, 3 метрики"
# Approver уже назначен в 01_setup.sh — можно создавать
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_EXPR" -X POST "$API/experiments" \
  -H "Content-Type: application/json" -d "$EXP_PAYLOAD")
check_status "$(echo "$RESP" | tail -1)" 201 "create experiment"
pretty "$(echo "$RESP" | head -1)"

step "3.2 Попытка запустить DRAFT → 409 (недопустимый переход)"
expect "HTTP 409"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_EXPR" -X POST "$API/experiments/status/running" \
  -H "Content-Type: application/json" -d '{"code":"exp_button_color"}')
check_status "$(echo "$RESP" | tail -1)" 409 "block running from DRAFT"

step "3.3 DRAFT → IN_REVIEW"
expect "HTTP 202, status=IN_REVIEW"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_EXPR" -X POST "$API/experiments/status/review" \
  -H "Content-Type: application/json" -d '{"code":"exp_button_color"}')
check_status "$(echo "$RESP" | tail -1)" 202 "to review"
echo "  status: $(echo "$RESP" | head -1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))")"

step "3.4 Viewer пытается ревьюировать → 403"
expect "HTTP 403 — только APPR может ревьюировать"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_VIEW" -X POST "$API/reviews" \
  -H "Content-Type: application/json" \
  -d '{"experiment_code":"exp_button_color","result":"APPROVED","comment":"test"}')
check_status "$(echo "$RESP" | tail -1)" 403 "viewer cannot review"

step "3.5 Завершение ревью без одобрений → REWORK/REJECTED"
expect "Статус НЕ APPROVED (required=1, approved=0)"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_EXPR" -X POST "$API/experiments/status/stop-review" \
  -H "Content-Type: application/json" -d '{"code":"exp_button_color"}')
check_status "$(echo "$RESP" | tail -1)" 202 "stop-review without approvals"
NEW_STATUS=$(echo "$RESP" | head -1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))")
echo "  Новый статус: $NEW_STATUS (ожидается REWORK или REJECTED)"

step "3.5.1 Попытка IN_REVIEW без изменений → 422"
expect "HTTP 409 — block review without changes"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_EXPR" -X POST "$API/experiments/status/review" \
  -H "Content-Type: application/json" -d '{"code":"exp_button_color"}')
check_status "$(echo "$RESP" | tail -1)" 409 "block review without changes"

step "3.5.2 Изменение версии эксперимента 1.0 → 1.1"
expect "HTTP 200, version=1.1"

UPDATE_PAYLOAD='{
  "name":"Тест цвета кнопки Купить (обновлено)",
  "description":"Проверяем: синяя или зелёная кнопка даёт больше конверсий (исправлена метрика)",
  "part":100,
  "version":1.1,
  "variants":[
    {"name":"control_green","value":"green","weight":50,"isControl":true},
    {"name":"variant_blue","value":"blue","weight":50,"isControl":false}
  ],
  "metrics":[
    {"metricCatalog_code":"CONVERSION_RATE","role":"MAIN"},
    {"metricCatalog_code":"ERROR_RATE","role":"GUARDRAIL","window":7200,"threshold":30,"action_code":"PAUSE"},
    {"metricCatalog_code":"CONVERSIONS","role":"ADDITIONAL"}
  ]
}'

RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_EXPR" -X PUT "$API/experiments/exp_button_color" \
  -H "Content-Type: application/json" -d "$UPDATE_PAYLOAD")
check_status "$(echo "$RESP" | tail -1)" 200 "update experiment version"
NEW_VERSION=$(echo "$RESP" | head -1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('version',0))")
echo "  → Версия обновлена до: $NEW_VERSION"

step "3.6 Возврат в DRAFT и повторная отправка на ревью"
if [ "$NEW_STATUS" = "REJECTED" ]; then
  curl -s -b "$COOKIE_EXPR" -X POST "$API/experiments/status/draft" \
    -H "Content-Type: application/json" -d '{"code":"exp_button_color"}' > /dev/null
  echo "  → REJECTED: сначала переведён в DRAFT"
fi

RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_EXPR" -X POST "$API/experiments/status/review" \
  -H "Content-Type: application/json" -d '{"code":"exp_button_color"}')
HTTP_CODE=$(echo "$RESP" | tail -1)
check_status "$HTTP_CODE" 202 "to review after changes"
BODY=$(echo "$RESP" | head -1)
CURRENT_STATUS=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))")
echo "  → Статус: $CURRENT_STATUS"

step "3.7 Approver одобряет (версия 1.1)"
expect "HTTP 201, result=APPROVED"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_APPR" -X POST "$API/reviews" \
  -H "Content-Type: application/json" \
  -d '{"experiment_code":"exp_button_color","result":"APPROVED","comment":"Версия 1.1 одобрена"}')
check_status "$(echo "$RESP" | tail -1)" 201 "approver review v1.1"
pretty "$(echo "$RESP" | head -1)"

step "3.8 stop-review → APPROVED (required=1 выполнен)"
expect "HTTP 202, status=APPROVED"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_EXPR" -X POST "$API/experiments/status/stop-review" \
  -H "Content-Type: application/json" -d '{"code":"exp_button_color"}')
check_status "$(echo "$RESP" | tail -1)" 202 "stop-review → APPROVED"
echo "  Статус: $(echo "$RESP" | head -1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))")"

step "3.9 Просмотр всех ревью"
expect "HTTP 200, required=1, items с result=APPROVED"
RESP=$(curl -s -b "$COOKIE_ADMIN" "$API/reviews/all/exp_button_color")
echo "$RESP" | python3 -c "
import sys,json; d=json.load(sys.stdin)
print(f'  required: {d.get(\"required\")}')
for r in d.get('items',[]): print(f'  - result: {r[\"result\"]} | comment: {r.get(\"comment\",\"\")[:50]}')
"

step "3.10 APPROVED → RUNNING"
expect "HTTP 202, status=RUNNING"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_EXPR" -X POST "$API/experiments/status/running" \
  -H "Content-Type: application/json" -d '{"code":"exp_button_color"}')
check_status "$(echo "$RESP" | tail -1)" 202 "to running"
echo "  Статус: $(echo "$RESP" | head -1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))")"

step "3.11 Второй эксперимент на тот же флаг → 409"
expect "HTTP 403 — conflict: same flag"
curl -s -b "$COOKIE_ADMIN" -X POST "$API/experiments" \
  -H "Content-Type: application/json" \
  -d '{"code":"exp_btn_v2","flag_code":"button_color","name":"Конфликт","description":"test","part":50,"version":1.0,
       "variants":[{"name":"ctrl","value":"green","weight":25,"isControl":true},{"name":"var","value":"red","weight":25,"isControl":false}],
       "metrics":[{"metricCatalog_code":"CONVERSIONS","role":"MAIN"}]}' > /dev/null
curl -s -b "$COOKIE_ADMIN" -X POST "$API/experiments/status/review" \
  -H "Content-Type: application/json" -d '{"code":"exp_btn_v2"}' > /dev/null
curl -s -b "$COOKIE_ADMIN" -X POST "$API/experiments/status/stop-review" \
  -H "Content-Type: application/json" -d '{"code":"exp_btn_v2"}' > /dev/null
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_ADMIN" -X POST "$API/experiments/status/running" \
  -H "Content-Type: application/json" -d '{"code":"exp_btn_v2"}')
check_status "$(echo "$RESP" | tail -1)" 403 "conflict: same flag"

step "3.12 История версий"
expect "HTTP 200, список версий exp_button_color"
RESP=$(curl -s -b "$COOKIE_ADMIN" "$API/experiments/history/exp_button_color")
echo "$RESP" | python3 -c "
import sys,json; d=json.load(sys.stdin)
for v in d.get('versions',[]): print(f'  version {v[\"version\"]}: status={v[\"status\"]} isCurrent={v[\"isCurrent\"]}')
"

section "03 LIFECYCLE — ЗАВЕРШЕНО. exp_button_color в статусе RUNNING"
