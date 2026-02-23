#!/usr/bin/env bash
# env.sh — переменные окружения для демо-скриптов
# Запускать через: source env.sh

export BASE_URL="http://localhost"
export API="$BASE_URL/api/v1"

# Реквизиты первого Admin (берутся из .env или config)
# Замените на актуальные значения из src/.env
export ADMIN_EMAIL="admin@lotty.ru"
export ADMIN_PASSWORD="admin123"

# Файл для хранения state между скриптами (токены, UUID)
export STATE_FILE="/tmp/lotty_demo_state"

# ── helpers ──────────────────────────────────────────────────────────────────
save_state() { echo "export $1=\"$2\"" >> "$STATE_FILE"; }

load_state() {
  if [ -f "$STATE_FILE" ]; then
    source "$STATE_FILE"
  fi
}

pretty() {
  # Красивый вывод JSON если установлен jq, иначе cat
  if command -v jq &>/dev/null; then
    echo "$1" | jq .
  else
    echo "$1"
  fi
}

section() {
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  $1"
  echo "═══════════════════════════════════════════════════════"
}

step() {
  echo ""
  echo "──────────────────────────────────────────"
  echo "  ШАГ: $1"
  echo "──────────────────────────────────────────"
}

expect() {
  echo "  EXPECT: $1"
}

check_status() {
  local status="$1"
  local expected="$2"
  local label="$3"
  if [ "$status" -eq "$expected" ]; then
    echo "  ✅ OK ($status)"
  else
    echo "  ❌ FAIL: ожидался $expected, получен $status — $label"
  fi
}
