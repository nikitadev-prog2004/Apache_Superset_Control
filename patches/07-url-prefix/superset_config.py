# Production overrides for the Superset test deployment.
import os

from flask import redirect, request

# Requirement 6: open a dashboard instead of the default welcome page.
# Uses the "World Bank's Data" example dashboard (slug: world_health).
WELCOME_DASHBOARD_SLUG = "world_health"

# Requirement 7: logo and post-login navigation without /superset/ prefix.
LOGO_TARGET_PATH = "/welcome/"

FEATURE_FLAGS = {
    "DASHBOARD_RBAC": True,
}

# Bust browser caches after frontend URL-prefix patches (requirement 7).
STATIC_ASSETS_VERSION = "7"
SEND_FILE_MAX_AGE_DEFAULT = 0


def FLASK_APP_MUTATOR(app):  # noqa: N802
    """Redirect legacy /superset/* URLs to their prefix-free equivalents."""

    @app.before_request
    def redirect_legacy_superset_urls():  # noqa: N802
        path = request.path
        if path == "/superset" or path.startswith("/superset/"):
            new_path = path.removeprefix("/superset") or "/"
            return redirect(new_path, code=301)


SQLALCHEMY_DATABASE_URI = os.getenv(
    "SUPERSET__SQLALCHEMY_DATABASE_URI",
    "postgresql+psycopg2://superset:superset@db:5432/superset",
)
SQLALCHEMY_EXAMPLES_URI = os.getenv(
    "SUPERSET__SQLALCHEMY_EXAMPLES_URI",
    "postgresql+psycopg2://examples:examples@db:5432/examples",
)
