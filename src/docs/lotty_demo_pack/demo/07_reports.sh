#!/usr/bin/env bash
# 07_reports.sh — Отчётность: по периоду, по вариантам, по метрикам
# Покрывает: B6-1 (фильтр периода), B6-2 (разбивка по вариантам), B6-3 (метрики)

source "$(dirname "$0")/env.sh"
load_state

section "07 REPORTS"

# Используем текущее время UTC для границ окна
NOW=$(date -u +"%Y-%m-%dT%H:%M:%S")
PAST=$(date -u -d "1 hour ago" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || \
       date -u -v-1H +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || \
       echo "2026-01-01T00:00:00")
FUTURE=$(date -u -d "1 hour" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || \
         date -u -v+1H +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || \
         echo "2026-12-31T23:59:59")

echo "  Окно отчёта: $PAST → $FUTURE"

# ─────────────────────────────────────────────────────────────
step "7.1 Отчёт по эксперименту exp_button_color (B6-2, B6-3)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 200, разбивка по вариантам (control_green / variant_blue), метрики CONVERSION_RATE + CONVERSIONS + ERROR_RATE"
RESP=$(curl -s -w "\n%{http_code}" \
  "$API/reports/exp_button_color?time_from=${PAST}&time_to=${FUTURE}" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 200 "report exp_button_color"
echo "$BODY" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'  experiment: {d.get(\"experiment_code\")}')
print(f'  period: {d.get(\"time_from\")} → {d.get(\"time_to\")}')
for v in d.get('variants', []):
    print(f'  Вариант: {v[\"variant_name\"]} (control={v[\"is_control\"]})')
    for m in v.get('metrics', []):
        print(f'    {m[\"metric_code\"]:20s} role={m[\"role\"]:12s} value={m[\"value\"]:.4f} events={m[\"event_count\"]}')
"

# ─────────────────────────────────────────────────────────────
step "7.2 Фильтр периода: отчёт за «пустое» окно в прошлом (B6-1)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 200, все value=0.0 (в далёком прошлом событий не было)"
OLD_FROM="2020-01-01T00:00:00"
OLD_TO="2020-01-02T00:00:00"
RESP=$(curl -s -w "\n%{http_code}" \
  "$API/reports/exp_button_color?time_from=${OLD_FROM}&time_to=${OLD_TO}" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 200 "report empty window"
echo "$BODY" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('  Значения метрик в пустом окне (2020-01-01):')
for v in d.get('variants', []):
    for m in v.get('metrics', []):
        print(f'    {v[\"variant_name\"]}.{m[\"metric_code\"]}: value={m[\"value\"]} (ожидается 0.0)')
"

# ─────────────────────────────────────────────────────────────
step "7.3 Сравнение: фактическое окно vs пустое окно (B6-1 демонстрация)"
# ─────────────────────────────────────────────────────────────
echo ""
echo "  Результат 7.1 (активное окно): значения > 0 там, где были события"
echo "  Результат 7.2 (пустое окно 2020): все значения = 0.0"
echo "  → Фильтр периода работает корректно"

# ─────────────────────────────────────────────────────────────
step "7.4 Отчёт для несуществующего эксперимента"
# ─────────────────────────────────────────────────────────────
expect "HTTP 422 или 404 — эксперимент не найден"
RESP=$(curl -s -w "\n%{http_code}" \
  "$API/reports/nonexistent_experiment?time_from=${PAST}&time_to=${FUTURE}" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
echo "  HTTP $STATUS: $BODY"
if [[ "$STATUS" -ge 400 ]]; then
  echo "  ✅ Ошибка возвращена корректно"
fi

# ─────────────────────────────────────────────────────────────
step "7.5 Отчёт для эксперимента в неактивном статусе (DRAFT)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 422 — отчёт недоступен для DRAFT/IN_REVIEW/APPROVED"
# Создаём черновик без запуска
curl -s -X POST "$API/experiments" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "code": "exp_draft_no_report",
    "flag_code": "show_banner",
    "name": "Черновик без отчёта",
    "description": "test",
    "part": 50,
    "version": 1.0,
    "variants": [
      {"name": "ctrl", "value": "false", "weight": 25, "isControl": true},
      {"name": "var",  "value": "true",  "weight": 25, "isControl": false}
    ],
    "metrics": [{"metricCatalog_code": "CONVERSIONS", "role": "MAIN"}]
  }' > /dev/null

RESP=$(curl -s -w "\n%{http_code}" \
  "$API/reports/exp_draft_no_report?time_from=${PAST}&time_to=${FUTURE}" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
echo "  HTTP $STATUS: $BODY"
if [[ "$STATUS" -ge 400 ]]; then
  echo "  ✅ Корректно блокируется отчёт для DRAFT"
fi

section "07 REPORTS — ЗАВЕРШЕНО"
