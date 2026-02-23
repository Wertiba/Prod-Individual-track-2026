# LOTTY A/B Platform — Пакет демо-данных для сдачи (Часть D)

## Структура пакета

```
demo/
├── 00_README.md          ← этот файл
├── 01_setup.sh           ← инициализация: логин, создание пользователей, каталоги
├── 02_flags.sh           ← Feature Flags (B2)
├── 03_experiment_lifecycle.sh  ← Жизненный цикл + ревью (B3)
├── 04_decide.sh          ← Decide API: default/variant/детерминизм (B2)
├── 05_events.sh          ← Приём событий, дедупликация, валидация (B4)
├── 06_guardrails.sh      ← Guardrails: срабатывание + аудит (B5)
├── 07_reports.sh         ← Отчётность по периоду и вариантам (B6)
├── 08_complete.sh        ← Завершение эксперимента ROLLOUT/ROLLBACK (B6)
├── 09_negative.sh        ← Негативные сценарии (B3/B4/B8)
├── 10_health.sh          ← Health & Readiness (B9)
└── env.sh                ← Переменные окружения (BASE_URL и т.д.)
```

## Порядок запуска

```bash
# 1. Убедитесь, что система запущена
docker compose up -d
curl http://localhost/api/v1/ready

# 2. Запустите скрипты по порядку
cd demo
chmod +x *.sh
source env.sh

./01_setup.sh        # создаём пользователей, каталоги — ОБЯЗАТЕЛЬНО ПЕРВЫМ
./02_flags.sh        # флаги
./03_experiment_lifecycle.sh   # эксперимент и ревью
./04_decide.sh       # decide API
./05_events.sh       # события
./06_guardrails.sh   # guardrail срабатывает
./07_reports.sh      # отчёт
./08_complete.sh     # завершение
./09_negative.sh     # негативные тесты
./10_health.sh       # health/ready
```

## Важно

- Каждый скрипт выводит ожидаемый результат (`EXPECT:`) перед запросом.
- UUID'ы сохраняются в файл `/tmp/lotty_demo_state` и переиспользуются между скриптами.
- Если нужно начать заново: `rm /tmp/lotty_demo_state` и перезапустить с `01_setup.sh`.
- BASE_URL по умолчанию `http://localhost` — порт 80 согласно docker-compose.yml.
