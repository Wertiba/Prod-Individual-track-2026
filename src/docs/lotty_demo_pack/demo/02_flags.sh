#!/usr/bin/env bash
# 02_flags.sh — Feature Flags: создание, просмотр, обновление default
# Покрывает: B2-1 (default), B7-1 (нейминг)

source "$(dirname "$0")/env.sh"
load_state

section "02 FEATURE FLAGS"

# ─────────────────────────────────────────────────────────────
step "2.1 Создание флага button_color (STRING)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 201, code=button_color, default=green, type=STRING"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/flags" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "code": "button_color",
    "default": "green",
    "type": "STRING"
  }')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 201 "create flag button_color"
pretty "$BODY"

# ─────────────────────────────────────────────────────────────
step "2.2 Создание флага show_banner (BOOL)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 201, code=show_banner, default=false"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$API/flags" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "code": "show_banner",
    "default": "false",
    "type": "BOOL"
  }')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 201 "create flag show_banner"

# ─────────────────────────────────────────────────────────────
step "2.3 Получение флага по коду"
# ─────────────────────────────────────────────────────────────
expect "HTTP 200, флаг button_color с default=green"
RESP=$(curl -s -w "\n%{http_code}" "$API/flags/button_color" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 200 "get flag"
pretty "$BODY"

# ─────────────────────────────────────────────────────────────
step "2.4 Список всех флагов"
# ─────────────────────────────────────────────────────────────
expect "HTTP 200, список с button_color и show_banner"
RESP=$(curl -s -w "\n%{http_code}" "$API/flags" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 200 "list flags"
echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); [print('  -', f['code'], '| default:', f['default']) for f in d.get('items',[])]"

# ─────────────────────────────────────────────────────────────
step "2.5 Обновление default-значения флага"
# ─────────────────────────────────────────────────────────────
expect "HTTP 200, default изменился с green на blue"
RESP=$(curl -s -w "\n%{http_code}" -X PATCH "$API/flags/button_color" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"default": "blue"}')
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 200 "update flag default"
pretty "$BODY"

# Возвращаем обратно green для чистоты демо
curl -s -X PATCH "$API/flags/button_color" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"default": "green"}' > /dev/null

echo ""
echo "  ✅ Флаг button_color возвращён к default=green для дальнейших сценариев"

section "02 FLAGS — ЗАВЕРШЕНО"
