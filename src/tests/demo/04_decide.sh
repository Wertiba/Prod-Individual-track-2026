#!/usr/bin/env bash
# 04_decide.sh — Decide API: default/variant, детерминизм, веса
source "$(dirname "$0")/env.sh"
load_state

section "04 DECIDE API"

step "4.1 Флаг БЕЗ эксперимента → default, decision_id=null"
expect "value=false (default show_banner), decision_id=null"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/decisions" \
  -H "Content-Type: application/json" \
  -d "{\"user_id\":\"$USER1_ID\",\"attributes\":{\"country\":\"RU\"},\"flag_codes\":[\"show_banner\"]}")
check_status "$(echo "$RESP" | tail -1)" 200 "decide no experiment"
echo "$RESP" | head -1 | python3 -c "
import sys,json; d=json.load(sys.stdin)
for i in d.get('items',[]): print(f'  flag={i[\"flag_code\"]} value={i[\"value\"]} decision_id={i.get(\"decision_id\")}')
"

step "4.2 Решения для всех 5 пользователей (button_color, RUNNING)"
echo ""
for i in 1 2 3 4 5; do
  eval "UID=\$USER${i}_ID"
  RESP=$(curl -s -X POST "$API/decisions" \
    -H "Content-Type: application/json" \
    -d "{\"user_id\":\"$UID\",\"attributes\":{\"country\":\"RU\"},\"flag_codes\":[\"button_color\"]}")
  echo "$RESP" | python3 -c "
import sys,json; d=json.load(sys.stdin)
for i in d.get('items',[]): print(f'  user$i: value={i[\"value\"]} decision_id={str(i.get(\"decision_id\",\"нет\"))[:8]}...')
" 2>/dev/null
  # Сохраняем первый найденный decision_id
  if [ -z "$DECISION_ID_1" ]; then
    DEC=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); items=d.get('items',[]); print(items[0].get('decision_id','') or '')" 2>/dev/null)
    if [ -n "$DEC" ] && [ "$DEC" != "None" ]; then
      save_state "DECISION_ID_1" "$DEC"
      DECISION_ID_1="$DEC"
    fi
  fi
done

if [ -z "$DECISION_ID_1" ]; then
  echo "  ⚠️  Никто не попал в эксперимент — ищем среди всех пользователей..."
  for i in 1 2 3 4 5; do
    eval "UID=\$USER${i}_ID"
    DEC=$(curl -s -X POST "$API/decisions" -H "Content-Type: application/json" \
      -d "{\"user_id\":\"$UID\",\"attributes\":{},\"flag_codes\":[\"button_color\"]}" | \
      python3 -c "import sys,json; d=json.load(sys.stdin); items=d.get('items',[]); print(items[0].get('decision_id','') or '')" 2>/dev/null)
    if [ -n "$DEC" ] && [ "$DEC" != "None" ]; then
      save_state "DECISION_ID_1" "$DEC"; DECISION_ID_1="$DEC"
      echo "  → decision_id у user$i: $DEC"; break
    fi
  done
fi

step "4.3 Детерминизм: повторный запрос → то же значение"
expect "Значения идентичны шагу 4.2"
echo ""
for i in 1 2 3; do
  eval "UID=\$USER${i}_ID"
  RESP=$(curl -s -X POST "$API/decisions" -H "Content-Type: application/json" \
    -d "{\"user_id\":\"$UID\",\"attributes\":{\"country\":\"RU\"},\"flag_codes\":[\"button_color\"]}")
  echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); [print(f'  user$i (повтор): {i[\"value\"]}') for i in d.get('items',[])]" 2>/dev/null
done
echo "  → Сравните с шагом 4.2 — значения должны совпадать"

step "4.4 Несколько флагов в одном запросе"
expect "Два флага в ответе: button_color и show_banner"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/decisions" \
  -H "Content-Type: application/json" \
  -d "{\"user_id\":\"$USER1_ID\",\"attributes\":{},\"flag_codes\":[\"button_color\",\"show_banner\"]}")
check_status "$(echo "$RESP" | tail -1)" 200 "multi-flag"
echo "$RESP" | head -1 | python3 -c "import sys,json; d=json.load(sys.stdin); [print(f'  {i[\"flag_code\"]}: {i[\"value\"]}') for i in d.get('items',[])]"

step "4.5 Статистика распределения (веса 50/50)"
GREEN=0; BLUE=0; DEFAULT=0
for i in 1 2 3 4 5; do
  eval "UID=\$USER${i}_ID"
  VAL=$(curl -s -X POST "$API/decisions" -H "Content-Type: application/json" \
    -d "{\"user_id\":\"$UID\",\"attributes\":{},\"flag_codes\":[\"button_color\"]}" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d['items'][0]['value'] if d['items'] else '')" 2>/dev/null)
  case "$VAL" in green) ((GREEN++));; blue) ((BLUE++));; *) ((DEFAULT++));; esac
done
echo "  green (control): $GREEN | blue (variant): $BLUE | без decision: $DEFAULT"

section "04 DECIDE — ЗАВЕРШЕНО"
