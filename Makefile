.PHONY: build-base build up down verify logs

build-base:
	./build-production-image.sh

build:
	./build-custom-image.sh

up:
	docker-compose up -d

down:
	docker-compose down

verify:
	./scripts/verify-welcome-dashboard.sh
	./scripts/verify-url-prefix.sh

logs:
	docker-compose logs -f superset
