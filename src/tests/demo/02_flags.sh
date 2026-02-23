#!/usr/bin/env bash
# 02_flags.sh — Feature Flags: создание, просмотр, обновление default
source "$(dirname "$0")/env.sh"
load_state

section "02 FEATURE FLAGS"

step "2.1 Создание флага button_color (STRING)"
expect "HTTP 201, code=button_color, default=green"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_ADMIN" -X POST "$API/flags" \
  -H "Content-Type: application/json" \
  -d '{"code":"button_color","default":"green","type":"STRING"}')
check_status "$(echo "$RESP" | tail -1)" 201 "create flag button_color"
pretty "$(echo "$RESP" | head -1)"

step "2.2 Создание флага show_banner (BOOL)"
expect "HTTP 201"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_ADMIN" -X POST "$API/flags" \
  -H "Content-Type: application/json" \
  -d '{"code":"show_banner","default":"false","type":"BOOL"}')
check_status "$(echo "$RESP" | tail -1)" 201 "create flag show_banner"

step "2.3 Получение флага по коду"
expect "HTTP 200, default=green"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_ADMIN" "$API/flags/button_color")
check_status "$(echo "$RESP" | tail -1)" 200 "get flag"
pretty "$(echo "$RESP" | head -1)"

step "2.4 Список всех флагов"
RESP=$(curl -s -b "$COOKIE_ADMIN" "$API/flags")
echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); [print('  -', f['code'], '| default:', f['default']) for f in d.get('items',[])]"

step "2.5 Обновление default-значения"
expect "HTTP 200, default=blue"
RESP=$(curl -s -w "\n%{http_code}" -b "$COOKIE_ADMIN" -X PATCH "$API/flags/button_color" \
  -H "Content-Type: application/json" -d '{"default":"blue"}')
check_status "$(echo "$RESP" | tail -1)" 200 "update flag"
# Возвращаем green для дальнейших сценариев
curl -s -b "$COOKIE_ADMIN" -X PATCH "$API/flags/button_color" \
  -H "Content-Type: application/json" -d '{"default":"green"}' > /dev/null
echo "  → Флаг возвращён к green"

section "02 FLAGS — ЗАВЕРШЕНО"
