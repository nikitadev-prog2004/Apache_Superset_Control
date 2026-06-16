# Apache Superset 6.1.0 — Production Customization

Кастомный production Docker-образ Apache Superset **6.1.0** (сборка из исходников) с кастомизациями и `docker-compose` для локального запуска.

**Предварительно:** Docker Engine, BuildKit/buildx, доступ к `docker`. Клон upstream:

```bash
git clone --branch 6.1.0 --depth 1 https://github.com/apache/superset.git superset
chmod +x build-*.sh scripts/*.sh
```

---

## 1. Как собрать Docker-образ

Сборка в **два шага**: базовый production-образ из source, затем слой с кастомизациями.

**Шаг A — base-образ из исходников** (требование 1, ~30–60 мин):

```bash
./build-production-image.sh
```

Результат: образ `superset:6.1.0` (stage `lean` официального Dockerfile).

**Шаг B — кастомный образ** (требования 2–7: clickhouse-connect, favicon, logo, watermark, welcome dashboard, URL без `/superset/`):

```bash
./build-custom-image.sh
```

Скрипт применяет патчи к `superset/` и собирает финальный образ `superset:6.1.0` / `superset:production`.

Альтернатива через Makefile:

```bash
make build-base   # шаг A
make build        # шаг B
```

**Проверка clickhouse-connect после сборки:**

```bash
docker run --rm superset:6.1.0 python -c \
  "import importlib.metadata as m; print(m.version('clickhouse-connect'))"
```

---

## 2. Как запустить Superset

Production-подобный стек (PostgreSQL + Redis + init + app):

```bash
docker-compose up -d
```

| URL | Назначение |
|-----|------------|
| http://localhost:8088/login/ | Web UI |
| http://localhost:8088/health | Healthcheck |

**Тестовые пользователи** (создаются при init):

| Логин | Пароль | Роль |
|-------|--------|------|
| admin | admin | Admin |
| gamma | gamma | Gamma |

После входа открывается dashboard **World Bank's Data** (`/dashboard/world_health/`).

**Остановка:**

```bash
docker-compose down
```

**Проверка кастомизаций:**

```bash
./scripts/verify-welcome-dashboard.sh
./scripts/verify-url-prefix.sh
# или: make verify
```

> Пустой экран после обновления? **Ctrl+Shift+R** — сброс кэша старых JS-бандлов.

---

## 3. Что ещё изменил бы для Production

Текущий `docker-compose` **эмулирует** production (внешняя БД, Redis, отдельный init). Для реального prod добавил бы:

1. **Секреты** — `SUPERSET_SECRET_KEY`, пароли БД и admin через Vault / Docker secrets / K8s secrets, не plain text в compose.
2. **HTTPS** — reverse proxy (nginx/Traefik/ALB) с TLS, `ENABLE_PROXY_FIX = True`, корректные `X-Forwarded-*`.
3. **Celery workers** — отдельные контейнеры `worker` и `beat` для async-запросов, alerts/reports и тяжёлых задач.
4. **Масштабирование** — несколько реплик app за load balancer; Redis и PostgreSQL — managed-сервисы (RDS, ElastiCache) с backup/PITR.
5. **Мониторинг и логи** — Prometheus metrics, centralized logging (ELK/Loki), алерты на `/health` и ошибки Gunicorn.
6. **Frontend** — пересборка SPA из патченных исходников вместо `sed` по бандлам; фиксированный `STATIC_ASSETS_VERSION` через CI/CD.
7. **Безопасность** — OAuth/LDAP вместо `db` auth, CSP headers, rate limiting с Redis backend, регулярные обновления образа.
8. **Ресурсы** — limits/requests в orchestrator, отдельный node pool для Superset, tuning Gunicorn workers под нагрузку.

---

## Справка

| # | Задача | Где |
|---|--------|-----|
| 1 | Production-образ из source | `build-production-image.sh` |
| 2 | clickhouse-connect | `Dockerfile` |
| 3 | Убрать watermark | `patches/03-watermark/` |
| 4 | Favicon | `assets/favicon.png` |
| 5 | Logo | `assets/logo.png` |
| 6 | Welcome dashboard | `config/superset_config.py`, `scripts/post-init.sh` |
| 7 | URL без `/superset/` | `patches/07-url-prefix/`, `templates/` |

PR по задачам: [docs/PR-SPLIT.md](docs/PR-SPLIT.md).
