import json
import os

# Environment Variables
DYNAMODB_TABLE = os.environ.get('DYNAMODB_TABLE', '')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')

def lambda_handler(event, context):
    print(f"[INFO] Processing event in {ENVIRONMENT}")
    print(f"[DEBUG] Event: {json.dumps(event)}")

    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Hello from Lambda!'
        })
    }
