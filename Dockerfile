# Extend the production Superset 6.1.0 image with customizations.
ARG BASE_IMAGE=superset:6.1.0
FROM ${BASE_IMAGE}

USER root

# Requirement 3: remove "Powered by Apache Superset" from Settings → About
COPY superset/superset/views/base.py /app/superset/views/base.py

# Requirement 4: replace favicon
COPY assets/favicon.png /app/superset/static/assets/images/favicon.png

# Requirement 5: replace Superset logo
COPY assets/logo.png /app/superset/static/assets/images/superset-logo-horiz.png

# Requirement 6: dashboard as welcome page
# Requirement 7: remove /superset/ URL prefix
COPY config/superset_config.py /app/pythonpath/superset_config.py
COPY superset/superset/views/core.py /app/superset/views/core.py
COPY superset/superset/views/explore.py /app/superset/views/explore.py
COPY superset/superset/views/tags.py /app/superset/views/tags.py
COPY superset/superset/views/all_entities.py /app/superset/views/all_entities.py
COPY superset/superset/initialization/__init__.py /app/superset/initialization/__init__.py
COPY superset/superset/models/dashboard.py /app/superset/models/dashboard.py
COPY superset/superset/models/slice.py /app/superset/models/slice.py
COPY superset/superset/models/core.py /app/superset/models/core.py
COPY superset/superset/utils/core.py /app/superset/utils/core.py
COPY superset/superset/tasks/async_queries.py /app/superset/tasks/async_queries.py
COPY templates/superset/spa.html /app/superset/templates/superset/spa.html
COPY templates/superset/partials/asset_bundle.html /app/superset/templates/superset/partials/asset_bundle.html
COPY scripts/patch-frontend-urls.sh /app/scripts/patch-frontend-urls.sh
COPY scripts/post-init.sh /app/scripts/post-init.sh
COPY scripts/verify-welcome-dashboard.sh /app/scripts/verify-welcome-dashboard.sh
COPY scripts/verify-url-prefix.sh /app/scripts/verify-url-prefix.sh
RUN chmod +x /app/scripts/patch-frontend-urls.sh \
    /app/scripts/post-init.sh \
    /app/scripts/verify-welcome-dashboard.sh \
    /app/scripts/verify-url-prefix.sh && \
    /app/scripts/patch-frontend-urls.sh
ENV SUPERSET_CONFIG_PATH=/app/pythonpath/superset_config.py

# Requirement 2: ClickHouse driver + PostgreSQL driver for metadata DB
RUN . /app/.venv/bin/activate && \
    uv pip install \
    "clickhouse-connect>=0.13.0,<1.0" \
    psycopg2-binary

USER superset

CMD ["/app/docker/entrypoints/run-server.sh"]
