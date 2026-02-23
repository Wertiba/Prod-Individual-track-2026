#!/usr/bin/env bash
# 05_events.sh — Приём событий, дедупликация, валидация, атрибуция
# Покрывает: B4-1 (тип поля), B4-2 (обязательные поля), B4-3 (дедупликация),
#            B4-4 (экспозиция с decision_id), B1-5 (happy-path: событие принято)

source "$(dirname "$0")/env.sh"
load_state

section "05 EVENTS"

# Убеждаемся, что decision_id есть
if [ -z "$DECISION_ID_1" ]; then
  echo "  ⚠️  DECISION_ID_1 не найден. Запустите 04_decide.sh сначала."
  echo "  Пробуем получить decision_id сейчас..."
  for i in 1 2 3 4 5; do
    eval "UID=\$USER${i}_ID"
    DEC_ID=$(curl -s -X POST "$API/decisions" \
      -H "Content-Type: application/json" \
      -d "{\"user_id\":\"$UID\",\"attributes\":{},\"flag_codes\":[\"button_color\"]}" | \
      python3 -c "import sys,json; d=json.load(sys.stdin); items=d.get('items',[]); print(items[0]['decision_id'] if items and items[0].get('decision_id') else '')" 2>/dev/null)
    if [ -n "$DEC_ID" ]; then
      save_state "DECISION_ID_1" "$DEC_ID"
      DECISION_ID_1="$DEC_ID"
      echo "  Найден: $DEC_ID"
      break
    fi
  done
fi

# ─────────────────────────────────────────────────────────────
step "5.1 Happy-path: корректный батч событий (EXPOSURE + CONVERSION)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 207, accepted=2, duplicates=0, rejected=0"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/events" \
  -H "Content-Type: application/json" \
  -d "{
    \"events\": [
      {
        \"eventKey\": \"exp1-user1-exposure-001\",
        \"decision_id\": \"$DECISION_ID_1\",
        \"eventCatalog_code\": \"EXPOSURE\",
        \"data\": {\"screen\": \"checkout\"}
      },
      {
        \"eventKey\": \"exp1-user1-conversion-001\",
        \"decision_id\": \"$DECISION_ID_1\",
        \"eventCatalog_code\": \"CONVERSION\",
        \"data\": {\"screen\": \"checkout\"}
      }
    ]
  }")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 207 "events happy-path"
pretty "$BODY"

# ─────────────────────────────────────────────────────────────
step "5.2 Дедупликация: повторная отправка тех же событий (B4-3)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 207, accepted=0, duplicates=2 (те же eventKey)"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/events" \
  -H "Content-Type: application/json" \
  -d "{
    \"events\": [
      {
        \"eventKey\": \"exp1-user1-exposure-001\",
        \"decision_id\": \"$DECISION_ID_1\",
        \"eventCatalog_code\": \"EXPOSURE\",
        \"data\": {}
      },
      {
        \"eventKey\": \"exp1-user1-conversion-001\",
        \"decision_id\": \"$DECISION_ID_1\",
        \"eventCatalog_code\": \"CONVERSION\",
        \"data\": {}
      }
    ]
  }")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 207 "deduplication"
echo "$BODY" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  accepted={d[\"accepted\"]} duplicates={d[\"duplicates\"]} rejected={d[\"rejected\"]}')
"

# ─────────────────────────────────────────────────────────────
step "5.3 Валидация: событие без обязательного поля decision_id (B4-2)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 207, rejected=1 с описанием ошибки"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/events" \
  -H "Content-Type: application/json" \
  -d '{
    "events": [
      {
        "eventKey": "bad-event-no-decision",
        "eventCatalog_code": "EXPOSURE"
      }
    ]
  }')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 207 "validation: missing decision_id"
echo "$BODY" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  rejected={d[\"rejected\"]}')
for err in d.get('errors', []):
    print(f'  error: eventKey={err[\"eventKey\"]} | reason={err[\"reason\"]}')
"

# ─────────────────────────────────────────────────────────────
step "5.4 Валидация: событие с невалидным типом поля decision_id (B4-1)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 207, rejected=1 (decision_id не UUID)"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/events" \
  -H "Content-Type: application/json" \
  -d '{
    "events": [
      {
        "eventKey": "bad-event-invalid-uuid",
        "decision_id": "not-a-valid-uuid",
        "eventCatalog_code": "EXPOSURE",
        "data": {}
      }
    ]
  }')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 207 "validation: bad uuid"
echo "$BODY" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  rejected={d[\"rejected\"]}')
for err in d.get('errors', []):
    print(f'  error: {err[\"reason\"][:80]}')
"

# ─────────────────────────────────────────────────────────────
step "5.5 Батч с микс-событиями: часть валидная, часть нет"
# ─────────────────────────────────────────────────────────────
expect "HTTP 207, accepted=1, rejected=1, в errors — описание невалидного"
# Получаем decision_id второго пользователя (если есть)
load_state
DEC2=$(curl -s -X POST "$API/decisions" \
  -H "Content-Type: application/json" \
  -d "{\"user_id\":\"$USER2_ID\",\"attributes\":{},\"flag_codes\":[\"button_color\"]}" | \
  python3 -c "import sys,json; d=json.load(sys.stdin); items=d.get('items',[]); print(items[0].get('decision_id','') if items else '')" 2>/dev/null)

if [ -n "$DEC2" ]; then
  RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/events" \
    -H "Content-Type: application/json" \
    -d "{
      \"events\": [
        {
          \"eventKey\": \"user2-exposure-001\",
          \"decision_id\": \"$DEC2\",
          \"eventCatalog_code\": \"EXPOSURE\",
          \"data\": {\"screen\": \"home\"}
        },
        {
          \"eventKey\": \"bad-no-event-code\",
          \"decision_id\": \"$DEC2\"
        }
      ]
    }")
  STATUS=$(echo "$RESP" | tail -1)
  BODY=$(echo "$RESP" | head -1)
  check_status "$STATUS" 207 "mixed batch"
  pretty "$BODY"
  save_state "DECISION_ID_2" "$DEC2"
else
  echo "  ⚠️  User2 без decision_id (не в эксперименте). Пропускаем смешанный батч."
fi

# ─────────────────────────────────────────────────────────────
step "5.6 Отправка LATENCY-событий для метрики AVG_LATENCY"
# ─────────────────────────────────────────────────────────────
expect "HTTP 207, accepted=3 (латентности для отчёта)"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/events" \
  -H "Content-Type: application/json" \
  -d "{
    \"events\": [
      {\"eventKey\": \"lat-001\", \"decision_id\": \"$DECISION_ID_1\", \"eventCatalog_code\": \"LATENCY\", \"data\": {\"value_ms\": 120}},
      {\"eventKey\": \"lat-002\", \"decision_id\": \"$DECISION_ID_1\", \"eventCatalog_code\": \"LATENCY\", \"data\": {\"value_ms\": 95}},
      {\"eventKey\": \"lat-003\", \"decision_id\": \"$DECISION_ID_1\", \"eventCatalog_code\": \"LATENCY\", \"data\": {\"value_ms\": 200}}
    ]
  }")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 207 "latency events"
echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'  accepted={d[\"accepted\"]} rejected={d[\"rejected\"]}')"

section "05 EVENTS — ЗАВЕРШЕНО"
