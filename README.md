# Sentiment Analyzer

Real-time sentiment analysis pipeline on AWS.

## Status
🚧 In Development - Phase 1

## Tech Stack
- AWS Lambda
- SNS/SQS
- DynamoDB
- Terraform

## Setup

### Prerequisites
- Python 3.11.0 (use pyenv: `pyenv install 3.11.0`)
- Terraform 1.9.0 (use tfenv: `tfenv install 1.9.0`)
- AWS CLI configured

### Local Development
```bash
# Install Python dependencies
cd lambdas
pip install -r requirements-dev.txt

# Run tests
pytest

# Format code
black .
pylint lambda_function.py
```

### Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply
```
