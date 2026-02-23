#!/usr/bin/env bash
# 04_decide.sh — Decide API: default/variant, детерминизм, веса
# Покрывает: B2-1 (default без эксперимента), B2-2 (default без участия),
#            B2-3 (variant для участника), B2-4 (детерминизм), B2-5 (веса)

source "$(dirname "$0")/env.sh"
load_state

section "04 DECIDE API"

# ─────────────────────────────────────────────────────────────
step "4.1 Решение для флага БЕЗ активного эксперимента (B2-1)"
# ─────────────────────────────────────────────────────────────
expect "value=false (default флага show_banner), decision_id=null"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/decisions" \
  -H "Content-Type: application/json" \
  -d "{
    \"user_id\": \"$USER1_ID\",
    \"attributes\": {\"country\": \"RU\", \"platform\": \"ios\"},
    \"flag_codes\": [\"show_banner\"]
  }")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 200 "decide no experiment"
echo "$BODY" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for item in d.get('items', []):
    print(f'  flag: {item[\"flag_code\"]} | value: {item[\"value\"]} | decision_id: {item.get(\"decision_id\")} | experiment: {item.get(\"experiment_code\")}')
"

# ─────────────────────────────────────────────────────────────
step "4.2 Решения для ВСЕХ 5 тестовых пользователей (флаг button_color)"
# ─────────────────────────────────────────────────────────────
expect "Каждый пользователь получает green, blue или вариант — в зависимости от того, попал ли он в эксперимент"
echo ""
for i in 1 2 3 4 5; do
  eval "UID=\$USER${i}_ID"
  RESP=$(curl -s -X POST "$API/decisions" \
    -H "Content-Type: application/json" \
    -d "{
      \"user_id\": \"$UID\",
      \"attributes\": {\"country\": \"RU\"},
      \"flag_codes\": [\"button_color\"]
    }")
  echo "$RESP" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for item in d.get('items', []):
    dec_id = item.get('decision_id', 'нет - default')
    print(f'  user$i: value={item[\"value\"]} | decision_id={dec_id}')
" 2>/dev/null
  # Сохраняем decision_id первого пользователя с non-null
  if [ "$i" -eq 1 ]; then
    DEC_ID=$(echo "$RESP" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for item in d.get('items', []):
    if item.get('decision_id'):
        print(item['decision_id'])
        break
" 2>/dev/null)
    if [ -n "$DEC_ID" ]; then
      save_state "DECISION_ID_1" "$DEC_ID"
      echo "  → decision_id сохранён: $DEC_ID"
    fi
  fi
done

# Ищем первый попавший decision_id среди всех пользователей
load_state
if [ -z "$DECISION_ID_1" ]; then
  echo "  ⚠️  User1 не попал в эксперимент (default). Ищем среди остальных..."
  for i in 2 3 4 5; do
    eval "UID=\$USER${i}_ID"
    DEC_ID=$(curl -s -X POST "$API/decisions" \
      -H "Content-Type: application/json" \
      -d "{\"user_id\":\"$UID\",\"attributes\":{},\"flag_codes\":[\"button_color\"]}" | \
      python3 -c "
import sys, json
d = json.load(sys.stdin)
for item in d.get('items', []):
    if item.get('decision_id'):
        print(item['decision_id'])
        break
" 2>/dev/null)
    if [ -n "$DEC_ID" ]; then
      save_state "DECISION_ID_1" "$DEC_ID"
      echo "  → Найден decision_id у user$i: $DEC_ID"
      break
    fi
  done
fi

# ─────────────────────────────────────────────────────────────
step "4.3 Детерминизм: повторный запрос тех же пользователей (B2-4)"
# ─────────────────────────────────────────────────────────────
expect "Результаты идентичны шагу 4.2"
echo ""
for i in 1 2 3; do
  eval "UID=\$USER${i}_ID"
  RESP=$(curl -s -X POST "$API/decisions" \
    -H "Content-Type: application/json" \
    -d "{
      \"user_id\": \"$UID\",
      \"attributes\": {\"country\": \"RU\"},
      \"flag_codes\": [\"button_color\"]
    }")
  echo "$RESP" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for item in d.get('items', []):
    print(f'  user$i (повтор): value={item[\"value\"]}')
" 2>/dev/null
done
echo "  → Сравните с результатами шага 4.2 — значения должны совпадать"

# ─────────────────────────────────────────────────────────────
step "4.4 Запрос нескольких флагов одновременно"
# ─────────────────────────────────────────────────────────────
expect "Два флага в одном запросе: button_color и show_banner"
load_state
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/decisions" \
  -H "Content-Type: application/json" \
  -d "{
    \"user_id\": \"$USER1_ID\",
    \"attributes\": {\"country\": \"RU\", \"platform\": \"ios\"},
    \"flag_codes\": [\"button_color\", \"show_banner\"]
  }")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 200 "multi-flag decision"
echo "$BODY" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for item in d.get('items', []):
    print(f'  {item[\"flag_code\"]}: value={item[\"value\"]}')
"

# ─────────────────────────────────────────────────────────────
step "4.5 Подсчёт распределения вариантов (B2-5 — веса)"
# ─────────────────────────────────────────────────────────────
expect "Распределение ≈ 50/50 между green и blue (веса variant_pool)"
echo ""
GREEN=0; BLUE=0; DEFAULT=0
for i in 1 2 3 4 5; do
  eval "UID=\$USER${i}_ID"
  VAL=$(curl -s -X POST "$API/decisions" \
    -H "Content-Type: application/json" \
    -d "{\"user_id\":\"$UID\",\"attributes\":{},\"flag_codes\":[\"button_color\"]}" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d['items'][0]['value'] if d['items'] else '')" 2>/dev/null)
  case "$VAL" in
    green) ((GREEN++));;
    blue)  ((BLUE++));;
    *)     ((DEFAULT++));;
  esac
done
echo "  green (control): $GREEN"
echo "  blue (variant):  $BLUE"
echo "  default/no decision: $DEFAULT"
echo "  Итого пользователей: 5 (part=100%, веса 50/50)"

section "04 DECIDE — ЗАВЕРШЕНО"
