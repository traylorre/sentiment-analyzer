"""
Unit tests for ingestion Lambda handler.

Tests cover:
- Valid tweet ingestion
- Missing required fields
- Invalid JSON
- SNS publish failures
"""

import json
import pytest
from moto import mock_aws
import boto3


@pytest.fixture
def sns_client():
    """Mock SNS client using moto."""
    with mock_aws():
        client = boto3.client("sns", region_name="us-west-2")
        # Create mock topic
        response = client.create_topic(Name="test-topic")
        topic_arn = response["TopicArn"]
        yield client, topic_arn


@pytest.mark.unit
def test_valid_tweet_returns_200(mock_env_vars, valid_tweet, sns_client):
    """
    GIVEN a valid tweet
    WHEN lambda_handler is called
    THEN it should return 200 with SNS message ID
    """
    from lambda_function import lambda_handler

    # Call handler
    result = lambda_handler(valid_tweet, {})

    # Assert success
    assert result["statusCode"] == 200

    # Assert response contains expected fields
    body = json.loads(result["body"])
    assert body["tweet_id"] == valid_tweet["tweet_id"]
    assert "sns_message_id" in body


@pytest.mark.unit
def test_missing_tweet_id_returns_400(mock_env_vars, tweet_without_id, sns_client):
    """
    GIVEN a tweet missing tweet_id
    WHEN lambda_handler is called
    THEN it should return 400 with error message
    """
    from lambda_function import lambda_handler

    # Call handler
    result = lambda_handler(tweet_without_id, {})
    assert result["statusCode"] == 400

    # Assert error message mentions 'tweet_id'
    body = json.loads(result["body"])
    assert "error" in body
    assert "tweet_id" in body["error"]


@pytest.mark.unit
def test_missing_text_returns_400(mock_env_vars, tweet_without_text, sns_client):
    """
    GIVEN a tweet missing text
    WHEN lambda_handler is called
    THEN it should return 400 with error message
    """
    from lambda_function import lambda_handler

    # Call handler
    result = lambda_handler(tweet_without_text, {})
    assert result["statusCode"] == 400

    # Assert error message mentions 'text'
    body = json.loads(result["body"])
    assert "error" in body
    assert "text" in body["error"]


@pytest.mark.unit
def test_invalid_json_returns_400(mock_env_vars, invalid_json_event, sns_client):
    """
    GIVEN invalid JSON in body
    WHEN lambda_handler is called
    THEN it should return 400 with error message
    """
    from lambda_function import lambda_handler

    # Call handler
    result = lambda_handler(invalid_json_event, {})
    assert result["statusCode"] == 400

    # Assert error message
    body = json.loads(result["body"])
    assert "error" in body
    assert "JSON" in body["error"]
