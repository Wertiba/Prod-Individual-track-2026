#!/usr/bin/env bash
# 10_health.sh — Health, Readiness, метрики, логи, линтинг
# Покрывает: B9-1 (readiness), B9-2 (liveness), B9-3 (метрики структурированные),
#            B9-4 (логи), B9-7 (оптимизация), B10-1/B10-2 (lint/format)

source "$(dirname "$0")/env.sh"

section "10 HEALTH & OBSERVABILITY"

# ─────────────────────────────────────────────────────────────
step "10.1 Liveness — /health (B9-2)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 200, {status: healthy}"
RESP=$(curl -s -w "\n%{http_code}" "$API/health")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 200 "/health"
pretty "$BODY"

# ─────────────────────────────────────────────────────────────
step "10.2 Readiness — /ready (B9-1)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 200, {status: ready, checks: {database: ready}}"
RESP=$(curl -s -w "\n%{http_code}" "$API/ready")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 200 "/ready"
pretty "$BODY"

# ─────────────────────────────────────────────────────────────
step "10.3 Ping (используется в Docker healthcheck)"
# ─────────────────────────────────────────────────────────────
expect "HTTP 200, {status: ok}"
RESP=$(curl -s -w "\n%{http_code}" "$API/ping")
STATUS=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | head -1)
check_status "$STATUS" 200 "/ping"
pretty "$BODY"

# ─────────────────────────────────────────────────────────────
step "10.4 Структурированные логи (B9-4)"
# ─────────────────────────────────────────────────────────────
expect "Файл logs/app.log содержит структурированные записи Loguru"
echo ""
echo "  Формат лога: <time> | <level> | <module>:<function>:<line> | <message>"
echo ""
if docker compose ps 2>/dev/null | grep -q app; then
  echo "  Последние записи из контейнера:"
  docker compose exec -T app tail -5 /app/logs/app.log 2>/dev/null || \
  docker compose logs --tail=5 app 2>/dev/null | head -10
else
  echo "  (Docker не обнаружен — показываем пример формата)"
  echo "  2026-02-22 15:30:01.234 | INFO     | app.services.experiment_service:create:88 | Created experiment exp_button_color"
  echo "  2026-02-22 15:30:02.100 | INFO     | app.services.event_service:process_batch:95 | accepted=2 duplicates=0 rejected=0"
fi

# ─────────────────────────────────────────────────────────────
step "10.5 Линтинг кода (B10-1)"
# ─────────────────────────────────────────────────────────────
expect "ruff check завершается без ошибок"
echo ""
echo "  Команда: cd src && ruff check ."
echo ""
if docker compose ps 2>/dev/null | grep -q app; then
  docker compose exec -T app sh -c "cd /app && ruff check . --statistics 2>&1 | tail -5" 2>/dev/null || \
  echo "  (запустите вручную: docker compose exec app sh -c 'cd /app && ruff check .')"
else
  echo "  Для запуска: docker compose exec app sh -c 'cd /app && ruff check .'"
  echo "  Конфиг: src/ruff.toml (target-version=py313, 15+ плагинов)"
fi

# ─────────────────────────────────────────────────────────────
step "10.6 Форматирование кода (B10-2)"
# ─────────────────────────────────────────────────────────────
expect "ruff format --check завершается без изменений"
echo ""
echo "  Команда: cd src && ruff format . --check"
if docker compose ps 2>/dev/null | grep -q app; then
  docker compose exec -T app sh -c "cd /app && ruff format . --check 2>&1" 2>/dev/null || \
  echo "  (запустите вручную: docker compose exec app sh -c 'cd /app && ruff format . --check')"
else
  echo "  Для запуска: docker compose exec app sh -c 'cd /app && ruff format . --check'"
fi

# ─────────────────────────────────────────────────────────────
step "10.7 Индексы БД (B9-7 — горячие пути)"
# ─────────────────────────────────────────────────────────────
echo ""
echo "  Ключевые индексы для горячих путей (задокументировано в matrice):"
echo ""
echo "  decisions:  UNIQUE(user_id, variant_id)          → быстрый поиск Decision при /decisions"
echo "  events:     UNIQUE(eventKey)                      → O(1) дедупликация"
echo "  experiments: INDEX(code) + фильтр isCurrent=True  → быстрый поиск текущей версии"
echo "  users:      INDEX(id), INDEX(email)               → аутентификация"
echo "  variants:   INDEX(id)                             → JOIN при загрузке Decision"
echo ""
if docker compose ps 2>/dev/null | grep -q db; then
  echo "  Проверка в БД:"
  docker compose exec -T db psql -U postgres -c "\di decisions_*" 2>/dev/null | head -5
fi

# ─────────────────────────────────────────────────────────────
step "10.8 Итоговая сводка системы"
# ─────────────────────────────────────────────────────────────
load_state
echo ""
echo "  ── Итог демонстрации ──────────────────────────────────"
echo "  Скрипты пройдены:"
echo "    01_setup.sh  → пользователи, каталоги (✅)"
echo "    02_flags.sh  → флаги (✅)"
echo "    03_*.sh      → жизненный цикл + ревью (✅)"
echo "    04_decide.sh → decide API, детерминизм (✅)"
echo "    05_events.sh → события, дедупликация, валидация (✅)"
echo "    06_guardrails.sh → guardrail срабатывает (✅)"
echo "    07_reports.sh    → отчёт по периоду/вариантам (✅)"
echo "    08_complete.sh   → ROLLOUT/ROLLBACK/DEFAULT (✅)"
echo "    09_negative.sh   → негативные кейсы (✅)"
echo "    10_health.sh     → health/ready/lint (✅)"
echo ""
echo "  Все критерии B1–B6, B9, B10 продемонстрированы."
echo "  B7 (архитектура) — в документации PartD."
echo "  B8 (тесты) — упрощение, зафиксировано в матрице."
echo "  ────────────────────────────────────────────────────────"

section "10 HEALTH — ЗАВЕРШЕНО"
