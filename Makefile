.PHONY: setup test format lint clean deploy

setup:
	@echo "Setting up development environment..."
	cd lambdas && pip install -r requirements-dev.txt

test:
	cd lambdas && pytest

format:
	cd lambdas && black .

lint:
	cd lambdas && pylint lambda_function.py

clean:
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type d -name .pytest_cache -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete

deploy:
	cd terraform && terraform init && terraform apply
