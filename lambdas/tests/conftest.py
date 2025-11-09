"""
Shared pytest fixtures for Lambda tests.

Reference: https://docs.pytest.org/en/stable/reference/fixtures.html
"""
import pytest
import os


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
def invalid_tweet_missing_tweet_id():
    """
    Mismatches expected input format for ingestion Lambda.
    """
    return {
        'text': 'I love AWS Lambda! It makes serverless so easy.',
        'user_id': 'user_123',
        'created_at': '2024-01-15T10:30:00Z'
    }

@pytest.fixture
def invalid_tweet_missing_text():
    """
    Mismatches expected input format for ingestion Lambda.
    """
    return {
        'tweet_id': '1234567890',
        'user_id': 'user_123',
        'created_at': '2024-01-15T10:30:00Z'
    }

@pytest.fixture
def invalid_tweet_invalid_body():
    """
    Mismatches expected input format for ingestion Lambda.
    """
    return {
        'tweet_id': '1234567890',
        'text': 'I love AWS Lambda! It makes serverless so easy.',
        'user_id': 'user_123',
        'created_at': '2024-01-15T10:30:00Z',  # extra comma is invalid
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
