# Pull Request Split

Each requirement is delivered as a **separate PR merged into `main`**, in order.
Use `scripts/create-pr-branches.sh` to recreate branch history locally.

| PR | Branch | Requirement | Key files |
|----|--------|-------------|-----------|
| 1 | `feat/01-production-base-image` | Production image Superset 6.1.0 from source | `build-production-image.sh`, `.gitignore` |
| 2 | `feat/02-clickhouse-connect` | Install `clickhouse-connect` | `Dockerfile` (pip install), `build-clickhouse-image.sh` |
| 3 | `feat/03-remove-watermark` | Remove “Powered by Apache Superset” | `patches/03-watermark/` |
| 4 | `feat/04-custom-favicon` | Replace favicon | `assets/favicon.png`, `Dockerfile` COPY |
| 5 | `feat/05-custom-logo` | Replace logo | `assets/logo.png`, `Dockerfile` COPY |
| 6 | `feat/06-welcome-dashboard` | Start page = dashboard | `patches/06-welcome-dashboard/`, `config/superset_config.py`, `scripts/post-init.sh` |
| 7 | `feat/07-url-without-superset-prefix` | URLs without `/superset/` | `patches/07-url-prefix/`, `templates/`, `docker-compose.yml`, `README.md`, verify scripts |

## Merge order

```
main
 └─ PR1 (base build)
     └─ PR2 (clickhouse)
         └─ PR3 (watermark)
             └─ PR4 (favicon)
                 └─ PR5 (logo)
                     └─ PR6 (welcome dashboard)
                         └─ PR7 (URL routing + compose + docs)
```

After all PRs are merged, `main` contains the full production-like stack described in [README.md](../README.md).
