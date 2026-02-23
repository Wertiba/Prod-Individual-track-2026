#!/usr/bin/env bash
# 06_guardrails.sh — Guardrails: порог, срабатывание, действие, аудит
# Покрывает: B5-1 (metric_key), B5-2 (threshold), B5-3 (обнаружение),
#            B5-4 (действие PAUSE), B5-5 (аудит)

source "$(dirname "$0")/env.sh"
load_state

section "06 GUARDRAILS"

# ─────────────────────────────────────────────────────────────
step "6.1 Создаём второй эксперимент специально для демо guardrail"
# ─────────────────────────────────────────────────────────────
# Этот эксперимент имеет низкий порог ERROR_RATE = 1 (т.е. 1 ошибка на 1 показ = ratio >= 1)
expect "HTTP 201, эксперимент с guardrail threshold=1 и action=PAUSE"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/experiments" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "code": "exp_guardrail_demo",
    "flag_code": "show_banner",
    "name": "Демо срабатывания Guardrail",
    "description": "Эксперимент с низким порогом ошибок — для демо guardrail",
    "part": 100,
    "version": 1.0,
    "variants": [
      {"name": "control_off", "value": "false", "weight": 50, "isControl": true},
      {"name": "variant_on",  "value": "true",  "weight": 50, "isControl": false}
    ],
    "metrics": [
      {"metricCatalog_code": "CONVERSIONS", "role": "MAIN"},
      {"metricCatalog_code": "ERROR_RATE",  "role": "GUARDRAIL", "window": 86400, "threshold": 1, "action_code": "PAUSE"}
    ]
  }')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 201 "create guardrail experiment"
echo "  Guardrail: ERROR_RATE >= 1.0 → PAUSE"

# Запускаем через admin (required=0 у admin-пользователя)
curl -s -X POST "$API/experiments/status/review" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"code":"exp_guardrail_demo"}' > /dev/null

curl -s -X POST "$API/experiments/status/stop-review" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"code":"exp_guardrail_demo"}' > /dev/null

RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/experiments/status/running" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"code":"exp_guardrail_demo"}')
STATUS=$(echo "$RESP" | tail -1)
check_status "$STATUS" 202 "guardrail exp to RUNNING"

# ─────────────────────────────────────────────────────────────
step "6.2 Получаем решения для пользователей"
# ─────────────────────────────────────────────────────────────
GRD_DEC_IDS=()
for i in 1 2 3 4 5; do
  eval "UID=\$USER${i}_ID"
  DEC=$(curl -s -X POST "$API/decisions" \
    -H "Content-Type: application/json" \
    -d "{\"user_id\":\"$UID\",\"attributes\":{},\"flag_codes\":[\"show_banner\"]}" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); items=d.get('items',[]); print(items[0].get('decision_id','') if items else '')" 2>/dev/null)
  if [ -n "$DEC" ]; then
    GRD_DEC_IDS+=("$DEC")
    echo "  User$i → decision_id: $DEC"
  fi
done

if [ ${#GRD_DEC_IDS[@]} -eq 0 ]; then
  echo "  ⚠️ Нет decision_id для guardrail демо. Проверьте, что пользователи активны."
  section "06 GUARDRAILS — ПРОПУСК (нет decision_id)"
  exit 0
fi

GRD_DEC="${GRD_DEC_IDS[0]}"
save_state "GRD_DEC_ID" "$GRD_DEC"

# ─────────────────────────────────────────────────────────────
step "6.3 Проверка текущего статуса (должен быть RUNNING)"
# ─────────────────────────────────────────────────────────────
RESP=$(curl -s "$API/experiments/exp_guardrail_demo" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
echo "  Статус до: $(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))")"

# ─────────────────────────────────────────────────────────────
step "6.4 Отправляем события: 1 EXPOSURE + 2 ERROR (ERROR_RATE = 2/1 = 2.0 > threshold=1)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 207, accepted=3. После этого guardrail должен сработать → статус станет PAUSED"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/events" \
  -H "Content-Type: application/json" \
  -d "{
    \"events\": [
      {
        \"eventKey\": \"grd-exposure-001\",
        \"decision_id\": \"$GRD_DEC\",
        \"eventCatalog_code\": \"EXPOSURE\",
        \"data\": {\"screen\": \"banner\"}
      },
      {
        \"eventKey\": \"grd-error-001\",
        \"decision_id\": \"$GRD_DEC\",
        \"eventCatalog_code\": \"ERROR\",
        \"data\": {\"message\": \"NullPointerException\"}
      },
      {
        \"eventKey\": \"grd-error-002\",
        \"decision_id\": \"$GRD_DEC\",
        \"eventCatalog_code\": \"ERROR\",
        \"data\": {\"message\": \"TimeoutException\"}
      }
    ]
  }")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 207 "guardrail trigger events"
echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'  accepted={d[\"accepted\"]} rejected={d[\"rejected\"]}')"

# ─────────────────────────────────────────────────────────────
step "6.5 Проверка статуса эксперимента после срабатывания (B5-3 + B5-4)"
# ─────────────────────────────────────────────────────────────
expect "status=PAUSED (guardrail сработал, action=PAUSE)"
RESP=$(curl -s "$API/experiments/exp_guardrail_demo" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
NEW_STATUS=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))")
echo "  Статус после: $NEW_STATUS"
if [ "$NEW_STATUS" = "PAUSED" ]; then
  echo "  ✅ Guardrail сработал корректно: RUNNING → PAUSED"
else
  echo "  ❌ Ожидался PAUSED, получен $NEW_STATUS"
fi

# ─────────────────────────────────────────────────────────────
step "6.6 Просмотр истории срабатываний guardrail (B5-5)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 200, список записей с metric_code, threshold, actual_value, action, triggered_at"
RESP=$(curl -s -w "\n%{http_code}" "$API/experiments/guardrails/exp_guardrail_demo" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 200 "guardrail history"
echo "$BODY" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  Experiment: {d.get(\"code\")}')
for item in d.get('items', []):
    h = item.get('history', {})
    if h:
        print(f'  --- Срабатывание ---')
        print(f'    metric_code:  {h.get(\"metric_code\")}')
        print(f'    threshold:    {h.get(\"threshold\")}')
        print(f'    actual_value: {h.get(\"actual_value\")}')
        print(f'    action:       {h.get(\"action\")}')
        print(f'    triggered_at: {h.get(\"triggered_at\")}')
"

section "06 GUARDRAILS — ЗАВЕРШЕНО"
