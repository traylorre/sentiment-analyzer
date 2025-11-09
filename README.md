# Sentiment Analyzer

Real-time sentiment analysis pipeline on AWS.  ![Tests](https://github.com/traylorre/sentiment-analyzer/actions/workflows/test.yml/badge.svg)
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

### Quick Start
```bash
make setup    # Install dependencies
make test     # Run tests
make format   # Format code
make lint     # Lint code
make deploy   # Deploy to AWS
```
