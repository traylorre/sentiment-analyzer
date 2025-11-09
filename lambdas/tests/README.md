# Lambda Tests

## Quick Start

```bash
# Install test dependencies
pip install -r requirements-dev.txt

# Run all tests
pytest

# Run only unit tests
pytest -m unit

# Run with coverage
pytest --cov=lambda_function --cov-report=term-missing
```

## Test Structure

```
tests/
├── conftest.py          # Shared fixtures (mock env vars, sample data)
├── test_ingestion.py    # Ingestion Lambda tests
└── test_analysis.py     # Analysis Lambda tests (TODO)
```

## Mocking Strategy

We use [moto](https://github.com/getmoto/moto) to mock AWS services:
- **SNS** - Message publishing
- **SQS** - Queue operations
- **DynamoDB** - Table reads/writes
- **Comprehend** - Sentiment analysis (TODO)

No real AWS calls are made. Tests run locally without credentials.

## Writing Tests

### Fixtures Available

- `mock_env_vars` - Sets SNS_TOPIC_ARN, DYNAMODB_TABLE
- `valid_tweet` - Sample valid tweet data
- `tweet_without_id` - Missing tweet_id (for negative tests)
- `tweet_without_text` - Missing text (for negative tests)
- `invalid_json_event` - Malformed JSON body

### Example Test

```python
@pytest.mark.unit
def test_valid_tweet_returns_200(mock_env_vars, valid_tweet):
    from lambda_function import lambda_handler
    
    result = lambda_handler(valid_tweet, {})
    
    assert result['statusCode'] == 200
```

## References

- [pytest documentation](https://docs.pytest.org/)
- [moto documentation](https://docs.getmoto.org/)
- [AWS Lambda testing best practices](https://docs.aws.amazon.com/lambda/latest/dg/testing-functions.html)
