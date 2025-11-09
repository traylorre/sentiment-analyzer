"""
Shared pytest fixtures for Lambda tests.

Reference: https://docs.pytest.org/en/stable/reference/fixtures.html
"""
import pytest
import os

@pytest.fixture(autouse=True)
def aws_credentials(monkeypatch):
    """Mock AWS credentials for moto."""
    monkeypatch.setenv('AWS_DEFAULT_REGION', 'us-west-2')


@pytest.fixture
def mock_env_vars(monkeypatch):
    """
    Set environment variables required by Lambda handlers.
    
    Usage:
        def test_something(mock_env_vars):
            # SNS_TOPIC_ARN is now set
    """
    monkeypatch.setenv('SNS_TOPIC_ARN', 'arn:aws:sns:us-west-2:123456789012:test-topic')
    monkeypatch.setenv('DYNAMODB_TABLE', 'test-tweets-table')


@pytest.fixture
def valid_tweet():
    """
    Matches expected input format for ingestion Lambda.
    """
    return {
        'tweet_id': '1234567890',
        'text': 'I love AWS Lambda! It makes serverless so easy.',
        'user_id': 'user_123',
        'created_at': '2024-01-15T10:30:00Z'
    }

@pytest.fixture
def tweet_without_id():
    """
    Tweet missing required tweet_id field.
    """
    return {
        'text': 'I love AWS Lambda! It makes serverless so easy.',
        'user_id': 'user_123',
        'created_at': '2024-01-15T10:30:00Z'
    }

@pytest.fixture
def tweet_without_text():
    """
    Tweet missing required text field.
    """
    return {
        'tweet_id': '1234567890',
        'user_id': 'user_123',
        'created_at': '2024-01-15T10:30:00Z'
    }

@pytest.fixture
def invalid_json_event():
    """
    Event with malformed JSON body (for API Gateway invocation).
    """
    return {
        'body': '{invalid json syntax'  # Missing closing brace
    }

@pytest.fixture
def api_gateway_event(valid_tweet):
    """
    API Gateway event structure.
    
    Reference: https://docs.aws.amazon.com/lambda/latest/dg/services-apigateway.html
    """
    import json
    return {
        'body': json.dumps(valid_tweet),
        'headers': {'Content-Type': 'application/json'},
        'httpMethod': 'POST',
        'path': '/tweets'
    }
