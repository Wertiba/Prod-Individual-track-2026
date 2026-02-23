#!/usr/bin/env bash
# 03_experiment_lifecycle.sh — Полный жизненный цикл эксперимента + ревью
# Покрывает: B3-1 (draft→review), B3-2 (→approved), B3-3 (блокировка без одобрений),
#            B3-4 (недопустимые переходы), B3-5 (только назначенные approver'ы)

source "$(dirname "$0")/env.sh"
load_state

section "03 EXPERIMENT LIFECYCLE"

# ─────────────────────────────────────────────────────────────
step "3.1 Создание эксперимента (DRAFT) — Experimenter"
# ─────────────────────────────────────────────────────────────
expect "HTTP 201, status=DRAFT, 2 варианта (blue/red), 1 контрольный, метрики MAIN+GUARDRAIL"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/experiments" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $EXPR_TOKEN" \
  -d '{
    "code": "exp_button_color",
    "flag_code": "button_color",
    "name": "Тест цвета кнопки Купить",
    "description": "Проверяем: синяя или красная кнопка даёт больше конверсий",
    "part": 100,
    "version": 1.0,
    "variants": [
      {"name": "control_green", "value": "green", "weight": 50, "isControl": true},
      {"name": "variant_blue",  "value": "blue",  "weight": 50, "isControl": false}
    ],
    "metrics": [
      {"metricCatalog_code": "CONVERSION_RATE", "role": "MAIN"},
      {"metricCatalog_code": "ERROR_RATE", "role": "GUARDRAIL", "window": 3600, "threshold": 50, "action_code": "PAUSE"},
      {"metricCatalog_code": "CONVERSIONS",    "role": "ADDITIONAL"}
    ]
  }')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 201 "create experiment"
pretty "$BODY"

EXP_CODE="exp_button_color"
save_state "EXP_CODE" "$EXP_CODE"

# ─────────────────────────────────────────────────────────────
step "3.2 Попытка запустить DRAFT — должна заблокироваться (B3-4)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 422 — нельзя запустить эксперимент из статуса DRAFT"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/experiments/status/running" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $EXPR_TOKEN" \
  -d '{"code": "exp_button_color"}')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 422 "block running from DRAFT"
echo "  Ответ: $BODY"

# ─────────────────────────────────────────────────────────────
step "3.3 Отправка на ревью DRAFT → IN_REVIEW (B3-1)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 202, status=IN_REVIEW"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/experiments/status/review" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $EXPR_TOKEN" \
  -d '{"code": "exp_button_color"}')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 202 "to review"
echo "  status: $(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))")"

# ─────────────────────────────────────────────────────────────
step "3.4 Попытка одобрить от Viewer — должна быть заблокирована (B3-5)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 403 — Viewer не может ревьюить"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"viewer@lotty.ru","password":"view12345"}')
VIEWER_TOKEN=$(echo "$RESP" | head -1 | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('accessToken',''))")

RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/reviews" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $VIEWER_TOKEN" \
  -d '{"experiment_code":"exp_button_color","result":"APPROVED","comment":"ok"}')
STATUS=$(echo "$RESP" | tail -1)
check_status "$STATUS" 403 "viewer cannot review"
echo "  Ответ: $(echo "$RESP" | head -1)"

# ─────────────────────────────────────────────────────────────
step "3.5 Попытка завершить ревью без одобрений (B3-3)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 202, но result=REWORK или REJECTED (required=1, approved=0)"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/experiments/status/stop-review" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $EXPR_TOKEN" \
  -d '{"code": "exp_button_color"}')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 202 "stop-review without approvals"
NEW_STATUS=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))")
echo "  Новый статус: $NEW_STATUS (ожидается REWORK или REJECTED — не APPROVED)"

# ─────────────────────────────────────────────────────────────
step "3.6 Переводим обратно в DRAFT и повторяем ревью корректно"
# ─────────────────────────────────────────────────────────────
# Переход REJECTED/REWORK → DRAFT (через set_status_draft)
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/experiments/status/draft" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $EXPR_TOKEN" \
  -d '{"code": "exp_button_color"}')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
echo "  После /status/draft: $(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))")"

# Снова на ревью
curl -s -X POST "$API/experiments/status/review" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $EXPR_TOKEN" \
  -d '{"code": "exp_button_color"}' > /dev/null
echo "  Статус → IN_REVIEW"

# ─────────────────────────────────────────────────────────────
step "3.7 Approver одобряет эксперимент (B3-5)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 201, result=APPROVED в ревью"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/reviews" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $APPR_TOKEN" \
  -d '{
    "experiment_code": "exp_button_color",
    "result": "APPROVED",
    "comment": "Всё выглядит корректно: варианты, метрики, guardrail. Одобряю."
  }')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 201 "approver review"
pretty "$BODY"

REVIEW_ID=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))")
save_state "REVIEW_ID" "$REVIEW_ID"

# ─────────────────────────────────────────────────────────────
step "3.8 Завершение ревью → APPROVED (B3-2)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 202, status=APPROVED (порог 1 выполнен)"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/experiments/status/stop-review" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $EXPR_TOKEN" \
  -d '{"code": "exp_button_color"}')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 202 "stop-review → APPROVED"
echo "  Статус: $(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))")"

# ─────────────────────────────────────────────────────────────
step "3.9 Просмотр всех ревью эксперимента"
# ─────────────────────────────────────────────────────────────
expect "HTTP 200, список ревью с result=APPROVED"
RESP=$(curl -s -w "\n%{http_code}" "$API/reviews/all/exp_button_color" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 200 "get all reviews"
echo "$BODY" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  required: {d.get(\"required\")}')
for r in d.get('items', []):
    print(f'  - result: {r[\"result\"]} | comment: {r.get(\"comment\",\"\")}')
"

# ─────────────────────────────────────────────────────────────
step "3.10 Запуск эксперимента APPROVED → RUNNING"
# ─────────────────────────────────────────────────────────────
expect "HTTP 202, status=RUNNING"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/experiments/status/running" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $EXPR_TOKEN" \
  -d '{"code": "exp_button_color"}')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 202 "to running"
echo "  Статус: $(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))")"

# ─────────────────────────────────────────────────────────────
step "3.11 Попытка запустить второй эксперимент на тот же флаг (B2-3.1)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 422 — на флаг button_color уже есть RUNNING эксперимент"

# Создаём второй эксперимент через Admin с required=0
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/experiments" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "code": "exp_button_color_v2",
    "flag_code": "button_color",
    "name": "Второй тест кнопки (конфликт)",
    "description": "Должен заблокироваться при запуске",
    "part": 60,
    "version": 1.0,
    "variants": [
      {"name": "control", "value": "green", "weight": 30, "isControl": true},
      {"name": "yellow",  "value": "yellow","weight": 30, "isControl": false}
    ],
    "metrics": [{"metricCatalog_code": "CONVERSIONS", "role": "MAIN"}]
  }')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 201 "create conflicting experiment"

# Сразу пробуем запустить (обходим ревью через admin required=0)
curl -s -X POST "$API/experiments/status/review" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"code": "exp_button_color_v2"}' > /dev/null
curl -s -X POST "$API/experiments/status/stop-review" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"code": "exp_button_color_v2"}' > /dev/null

RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/experiments/status/running" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"code": "exp_button_color_v2"}')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 422 "conflict: second experiment on same flag"
echo "  Ответ: $BODY"

# ─────────────────────────────────────────────────────────────
step "3.12 История версий эксперимента"
# ─────────────────────────────────────────────────────────────
expect "HTTP 200, список версий эксперимента exp_button_color"
RESP=$(curl -s -w "\n%{http_code}" "$API/experiments/history/exp_button_color" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 200 "experiment history"
echo "$BODY" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for v in d.get('versions', []):
    print(f'  version {v[\"version\"]}: status={v[\"status\"]} isCurrent={v[\"isCurrent\"]}')
"

section "03 LIFECYCLE — ЗАВЕРШЕНО. Эксперимент exp_button_color в статусе RUNNING"
