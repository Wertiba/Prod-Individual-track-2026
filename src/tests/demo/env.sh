#!/usr/bin/env bash
# env.sh — переменные окружения и хелперы для демо-скриптов
# Запускать через: source env.sh

export BASE_URL="http://localhost"
export API="$BASE_URL/api/v1"

export ADMIN_EMAIL=admin@mail.ru
export ADMIN_PASSWORD=123123123aA!

export STATE_FILE="/tmp/lotty_demo_state"

# Файлы кук — у каждого пользователя свой файл
export COOKIE_ADMIN="/tmp/lotty_cookie_admin.txt"
export COOKIE_EXPR="/tmp/lotty_cookie_expr.txt"
export COOKIE_APPR="/tmp/lotty_cookie_appr.txt"
export COOKIE_VIEW="/tmp/lotty_cookie_view.txt"

save_state() { echo "export $1=\"$2\"" >> "$STATE_FILE"; }

load_state() {
  if [ -f "$STATE_FILE" ]; then source "$STATE_FILE"; fi
}

# login <email> <password> <cookie_file>
# Логинится, сохраняет куку, возвращает accessToken
login() {
  local email="$1" password="$2" cookie_file="$3"
  curl -s -c "$cookie_file" -X POST "$API/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('accessToken',''))"
}

pretty() {
  if command -v jq &>/dev/null; then echo "$1" | jq .
  else echo "$1"; fi
}

section() {
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  $1"
  echo "═══════════════════════════════════════════════════════"
}

step()   { echo ""; echo "──────────────────────────────────────────"; echo "  ШАГ: $1"; echo "──────────────────────────────────────────"; }
expect() { echo "  EXPECT: $1"; }

check_status() {
  local status="$1" expected="$2" label="$3"
  if [ "$status" -eq "$expected" ]; then echo "  ✅ OK ($status)"
  else echo "  ❌ FAIL: ожидался $expected, получен $status — $label"; fi
}
