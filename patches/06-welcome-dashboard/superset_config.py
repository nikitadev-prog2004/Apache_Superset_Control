# Requirement 6 only — welcome dashboard (merged before requirement 7).
import os

WELCOME_DASHBOARD_SLUG = "world_health"

FEATURE_FLAGS = {
    "DASHBOARD_RBAC": True,
}

SQLALCHEMY_DATABASE_URI = os.getenv(
    "SUPERSET__SQLALCHEMY_DATABASE_URI",
    "postgresql+psycopg2://superset:superset@db:5432/superset",
)
SQLALCHEMY_EXAMPLES_URI = os.getenv(
    "SUPERSET__SQLALCHEMY_EXAMPLES_URI",
    "postgresql+psycopg2://examples:examples@db:5432/examples",
)
