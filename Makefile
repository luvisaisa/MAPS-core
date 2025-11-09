.PHONY: help install test lint format clean

help:
	@echo "MAPS Development Commands"
	@echo "  install  - Install dependencies"
	@echo "  test     - Run tests"
	@echo "  lint     - Run linters"
	@echo "  format   - Format code with black"
	@echo "  clean    - Remove build artifacts"
	@echo "  api      - Start API server"

install:
	pip install -r requirements.txt
	pip install -e .

test:
	pytest -v

lint:
	flake8 src/ tests/
	mypy src/maps/

format:
	black src/ tests/ --line-length 100

clean:
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name '*.pyc' -delete
	rm -rf .pytest_cache
	rm -rf htmlcov
	rm -rf .coverage

api:
	python scripts/run_server.py
