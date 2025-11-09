.PHONY: setup test format lint clean deploy

VENV := venv
PYTHON := $(VENV)/bin/python
PIP := $(VENV)/bin/pip

setup:
	@echo "Setting up development environment..."
	python3 -m venv $(VENV)
	$(PIP) install -r lambdas/requirements-dev.txt
	@echo "✓ Setup complete. Activate with: source venv/bin/activate"

test:
	$(VENV)/bin/pytest lambdas/

format:
	$(VENV)/bin/black lambdas/

lint:
	$(VENV)/bin/pylint lambdas/lambda_function.py

clean:
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type d -name .pytest_cache -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	rm -rf $(VENV)

deploy:
	cd terraform && terraform init && terraform apply
