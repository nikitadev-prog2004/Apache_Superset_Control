# Apache Superset 6.1.0 — Production Customization

Кастомный production Docker-образ Apache Superset **6.1.0**, собранный из исходников, с семью доработками и `docker-compose` для локального запуска в production-подобной конфигурации.

## Требования (реализовано)

| # | Задача | Реализация |
|---|--------|------------|
| 1 | Production-образ Superset 6.1.0 из source | `build-production-image.sh` → образ `superset:6.1.0` (target `lean`) |
| 2 | Установка `clickhouse-connect` | `Dockerfile` → `uv pip install clickhouse-connect` |
| 3 | Убрать «Powered by Apache Superset» | `patches/03-watermark/` → `show_watermark: False` |
| 4 | Замена favicon | `assets/favicon.png` |
| 5 | Замена логотипа | `assets/logo.png` |
| 6 | Стартовый dashboard вместо welcome | `WELCOME_DASHBOARD_SLUG=world_health`, редирект на `/dashboard/world_health/` |
| 7 | URL без префикса `/superset/` | Backend routes + патч frontend bundles + `templates/` |

## Pull Request’ы

Каждая задача — **отдельный PR в `main`**. Порядок и файлы: [docs/PR-SPLIT.md](docs/PR-SPLIT.md).

Воспроизвести ветки локально:

```bash
chmod +x scripts/create-pr-branches.sh
./scripts/create-pr-branches.sh
```

## Быстрый старт

### Предварительные условия

- Docker Engine + BuildKit/buildx
- Пользователь в группе `docker` (или `newgrp docker`)
- Клон исходников Superset 6.1.0:

```bash
git clone --branch 6.1.0 --depth 1 https://github.com/apache/superset.git superset
```

### 1. Сборка base-образа из source (требование 1, ~30–60 мин)

```bash
chmod +x build-production-image.sh build-clickhouse-image.sh build-custom-image.sh scripts/*.sh
./build-production-image.sh
```

### 2. Сборка кастомного образа (требования 2–7, ~2 мин)

```bash
./build-custom-image.sh
```

Скрипт применяет патчи (`scripts/apply-patches.sh`) и собирает финальный образ `superset:6.1.0` / `superset:production`.

### 3. Запуск production-подобного стека

```bash
docker-compose up -d
```

| Сервис | Назначение |
|--------|------------|
| `db` | PostgreSQL 17 (metadata + examples DB) |
| `redis` | Кэш / Celery broker |
| `superset-init` | Миграции, admin, примеры, post-init |
| `superset` | Приложение на порту **8088** |

### 4. Проверка

```bash
./scripts/verify-welcome-dashboard.sh   # req 6: /welcome/ → dashboard
./scripts/verify-url-prefix.sh          # req 7: URL без /superset/
```

**UI:** http://localhost:8088/login/

| Пользователь | Пароль | Роль |
|--------------|--------|------|
| admin | admin | Admin |
| gamma | gamma | Gamma (доступ к welcome dashboard) |

После входа: редирект на `/dashboard/world_health/` (World Bank's Data).

> Если экран пустой — жёсткое обновление **Ctrl+Shift+R** (кэш старых JS-бандлов с маршрутами `/superset/`).

## Структура проекта

```
.
├── README.md
├── docker-compose.yml          # production-like stack
├── Dockerfile                  # слой кастомизаций поверх superset:6.1.0
├── build-production-image.sh   # req 1: сборка из source
├── build-clickhouse-image.sh   # сборка кастомного слоя
├── build-custom-image.sh       # патчи + сборка
├── assets/                     # favicon, logo (req 4–5)
├── config/superset_config.py   # production overrides
├── patches/                    # исходники патчей по PR (req 3, 6, 7)
├── templates/                  # spa.html, cache-bust (req 7)
├── scripts/
│   ├── apply-patches.sh
│   ├── post-init.sh            # gamma user + dashboard RBAC
│   ├── patch-frontend-urls.sh
│   ├── verify-*.sh
│   └── create-pr-branches.sh
├── docs/PR-SPLIT.md
└── superset/                   # upstream clone 6.1.0 (не в git, см. .gitignore)
```

## Makefile

```bash
make build-base    # req 1
make build         # req 2–7
make up            # docker-compose up -d
make down          # docker-compose down
make verify        # оба verify-скрипта
```

## Конфигурация (production-like)

- **Metadata DB:** PostgreSQL (`superset:superset@db:5432/superset`)
- **Examples DB:** PostgreSQL (`examples:examples@db:5432/examples`)
- **Redis:** `redis:6379`
- **Config:** `SUPERSET_CONFIG_PATH=/app/pythonpath/superset_config.py`
- **Secret key:** задаётся в `docker-compose.yml` (для теста; в prod — заменить)

## Проверка clickhouse-connect

```bash
docker run --rm superset:6.1.0 python -c \
  "import importlib.metadata as m; print(m.version('clickhouse-connect'))"
```

## Лицензия

Патчи к Apache Superset распространяются на условиях [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).
Исходники Superset — проект [Apache Superset](https://github.com/apache/superset).
