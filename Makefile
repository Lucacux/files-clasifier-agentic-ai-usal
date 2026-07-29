.PHONY: help install fmt lint types test test-unit check clean

help:  ## Muestra esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

install:  ## Instala el proyecto en modo editable con dependencias de desarrollo
	python -m pip install --upgrade pip
	pip install -e ".[dev]"
	pre-commit install

fmt:  ## Formatea el código
	ruff format .
	ruff check --fix .

lint:  ## Linter
	ruff format --check .
	ruff check .

types:  ## Chequeo de tipos
	mypy src/

test:  ## Todos los tests
	pytest --cov=archivista --cov-report=term-missing

test-unit:  ## Sólo tests unitarios (sin integración ni IA)
	pytest -m "not integration and not requires_ai"

check: lint types test  ## Todo lo que corre el CI

clean:  ## Limpia artefactos de build y caches
	rm -rf build/ dist/ *.egg-info .pytest_cache .mypy_cache .ruff_cache .coverage htmlcov
	find . -type d -name __pycache__ -exec rm -rf {} +
