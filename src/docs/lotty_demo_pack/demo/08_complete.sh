#!/usr/bin/env bash
# 08_complete.sh — Завершение эксперимента: ROLLOUT, ROLLBACK, DEFAULT (no effect)
# Покрывает: B6-4 (фиксация исхода), B6-5 (сохранение обоснования)
#            Демо: pause → resume → complete → archive

source "$(dirname "$0")/env.sh"
load_state

section "08 EXPERIMENT COMPLETION"

# ─────────────────────────────────────────────────────────────
step "8.1 Пауза основного эксперимента"
# ─────────────────────────────────────────────────────────────
expect "HTTP 202, status=PAUSED"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/experiments/status/paused" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $EXPR_TOKEN" \
  -d '{"code": "exp_button_color"}')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 202 "pause"
echo "  Статус: $(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))")"

# ─────────────────────────────────────────────────────────────
step "8.2 Возобновление (PAUSED → RUNNING)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 202, status=RUNNING"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/experiments/status/running" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $EXPR_TOKEN" \
  -d '{"code": "exp_button_color"}')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 202 "resume"
echo "  Статус: $(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))")"

# ─────────────────────────────────────────────────────────────
step "8.3 Завершение с результатом ROLLOUT (победитель определяется автоматически)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 202, status=COMPLETED, result=ROLLOUT, comment сохранён, resultVariant_id заполнен"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/experiments/status/completed" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $EXPR_TOKEN" \
  -d '{
    "code": "exp_button_color",
    "result": "ROLLOUT",
    "comment": "Вариант blue показал +15% к конверсии при незначительном росте ошибок. Принято решение о раскатке синей кнопки на всю аудиторию."
  }')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 202 "complete ROLLOUT"
echo "$BODY" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  status:           {d.get(\"status\")}')
print(f'  comment:          {d.get(\"comment\")}')
print(f'  resultVariant_id: {d.get(\"resultVariant_id\")}')
"

# ─────────────────────────────────────────────────────────────
step "8.4 Архивирование эксперимента COMPLETED → ARCHIVED"
# ─────────────────────────────────────────────────────────────
expect "HTTP 202, status=ARCHIVED"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/experiments/status/archived" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $EXPR_TOKEN" \
  -d '{"code": "exp_button_color"}')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 202 "archive"
echo "  Статус: $(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))")"

# ─────────────────────────────────────────────────────────────
step "8.5 Демо ROLLBACK: создаём и завершаем отдельный эксперимент"
# ─────────────────────────────────────────────────────────────
expect "HTTP 202, status=COMPLETED, result=ROLLBACK, resultVariant_id = control variant"

# Создаём через admin (быстрее — без ревью)
curl -s -X POST "$API/experiments" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "code": "exp_rollback_demo",
    "flag_code": "show_banner",
    "name": "Демо ROLLBACK",
    "description": "Эксперимент завершается откатом",
    "part": 60,
    "version": 1.0,
    "variants": [
      {"name": "control_off", "value": "false", "weight": 30, "isControl": true},
      {"name": "variant_on",  "value": "true",  "weight": 30, "isControl": false}
    ],
    "metrics": [{"metricCatalog_code": "CONVERSIONS", "role": "MAIN"}]
  }' > /dev/null

curl -s -X POST "$API/experiments/status/review" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"code":"exp_rollback_demo"}' > /dev/null

curl -s -X POST "$API/experiments/status/stop-review" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"code":"exp_rollback_demo"}' > /dev/null

curl -s -X POST "$API/experiments/status/running" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"code":"exp_rollback_demo"}' > /dev/null

echo "  Эксперимент exp_rollback_demo запущен. Завершаем с ROLLBACK..."

RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/experiments/status/completed" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "code": "exp_rollback_demo",
    "result": "ROLLBACK",
    "comment": "Вариант с баннером увеличил количество ошибок на 30%. Откатываемся к исходному поведению."
  }')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 202 "complete ROLLBACK"
echo "$BODY" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  status:           {d.get(\"status\")}')
print(f'  comment:          {d.get(\"comment\")}')
print(f'  resultVariant_id: {d.get(\"resultVariant_id\")} (должен быть control variant)')
"

# ─────────────────────────────────────────────────────────────
step "8.6 Демо DEFAULT (no effect)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 202, status=COMPLETED, resultVariant_id=null"

# Используем уже завершённый guardrail_demo (он PAUSED, можно завершить)
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/experiments/status/completed" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "code": "exp_guardrail_demo",
    "result": "DEFAULT",
    "comment": "Статистически значимого эффекта не обнаружено. Гипотеза отклонена. Закрываем и начинаем следующую итерацию."
  }')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 202 "complete DEFAULT/no-effect"
echo "$BODY" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  status:           {d.get(\"status\")}')
print(f'  comment:          {d.get(\"comment\")}')
print(f'  resultVariant_id: {d.get(\"resultVariant_id\")} (ожидается null)')
"

section "08 COMPLETION — ЗАВЕРШЕНО. Все три режима (ROLLOUT/ROLLBACK/DEFAULT) продемонстрированы"
