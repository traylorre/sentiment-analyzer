import json
import os
import boto3
from datetime import datetime, timezone

# Initialize AWS clients (reused)
sns_client = boto3.client('sns')

# Environment Variables
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']  # Fail fast if missing

def lambda_handler(event, context):
    try:
        if not isinstance(event, dict):
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Invalid JSON'})
            }
        body = json.loads(event.get('body', '{}')) if isinstance(event.get('body'), str) else event

        # Validate required fields
        required_fields = ['tweet_id', 'text']
        missing = [f for f in required_fields if f not in body]
        if missing:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': f'Missing fields: {missing}'})
            }
        time_now = datetime.now(timezone.utc).isoformat()

        # Hydrate
        message = {
            'tweet_id': body['tweet_id'],
            'text': body['text'],
            'user_id': body.get('user_id'),
            'created_at': body.get('created_at', time_now),
            'ingested_at': time_now
        }

        # SNS Publish
        response = sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Message=json.dumps(message),
            Subject='TweetIngested'
        )

        print(f"[INFO] Published tweet {message['tweet_id']} to SNS: {response['MessageId']}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Tweet ingested successfully',
                'tweet_id': message['tweet_id'],
                'sns_message_id': response['MessageId']
            })
        }

    except json.JSONDecodeError as e:
        print(f"[ERROR] Invalid JSON: {e}")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid JSON'})
        }
    
    except Exception as e:
        print(f'[ERROR] Unexpected error: {e}')
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }