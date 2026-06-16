#!/usr/bin/env bash
# Post-init customization for the Superset test deployment.

set -euo pipefail

echo "Creating non-admin test user (gamma / gamma)..."
superset fab create-user \
  --username gamma \
  --firstname Gamma \
  --lastname User \
  --email gamma@test.com \
  --password gamma \
  --role Gamma 2>/dev/null || echo "User 'gamma' already exists, skipping."

echo "Granting access to welcome dashboard for non-admin users..."
python <<'PY'
from superset.app import create_app

app = create_app()
with app.app_context():
    from superset import db, security_manager
    from superset.models.dashboard import Dashboard

    dashboard = Dashboard.get("world_health")
    if not dashboard:
        raise SystemExit("Welcome dashboard 'world_health' was not found")

    dashboard.published = True
    for role_name in ("Gamma", "Alpha"):
        role = security_manager.find_role(role_name)
        if role and role not in dashboard.roles:
            dashboard.roles.append(role)

    db.session.commit()
    print(
        f"Welcome dashboard ready: id={dashboard.id}, "
        f"title={dashboard.dashboard_title!r}"
    )
PY

echo "Post-init customization complete."
