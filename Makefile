SHELL := /bin/bash

.PHONY: help
help:
	@echo "Targets:"
	@echo "  make test-unit          Run Python unit tests"
	@echo "  make test-integration   Run compose-based smoke + persistence tests"
	@echo "  make up                 Start dev stack"
	@echo "  make down               Stop dev stack"
	@echo "  make logs               Tail core container logs"

.PHONY: test-unit
test-unit:
	python -m pip install --upgrade pip
	pip install -r app/requirements.txt
	pytest -q

.PHONY: up
up:
	docker compose up --build -d

.PHONY: down
down:
	docker compose down -v

.PHONY: logs
logs:
	docker compose logs -f --tail=200

.PHONY: test-integration
test-integration:
	bash tests/integration/run.sh
