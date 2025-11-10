# Sentiment Analyzer <img src="https://github.com/traylorre/sentiment-analyzer/actions/workflows/test.yml/badge.svg" align="right" alt="Tests">

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

### Quick Start
```bash
make                        # make setup; make test

source venv/bin/activate    # modifies current shell environment
                            # to prioritize python 3.11 and its package dependencies
make deploy                 # requires AWS environment
```
### Makefile Commands
```bash
make setup                  # Install dependencies
make test                   # Run tests

make lint                   # Lint code
make format                 # Format code

make clean                  # remove build artifacts
make deploy                 # Deploy to AWS
```
