terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags { # applies to all AWS resources
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# data.aws_caller_identity.current.account_id    # Your AWS Account ID
# data.aws_caller_identity.current.user_id       # The IAM user/role ID
# data.aws_caller_identity.current.arn           # Full ARN of the caller
data "aws_caller_identity" "current" {}
# data.aws_region.current.name              # Region name ("us-east-2")
# data.aws_region.current.endpoint          # AWS API endpoint for that region
# data.aws_region.current.description       # Human-readable string
data "aws_region" "current" {}

# create local variables throughout terraform
locals {
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.name
  name_prefix = "${var.project_name}-${var.environment}"

  # reusable map of tags that can be applied to resources
  # similar to default_tags but specific per resources
  common_tags = {
    Phase = "phase-1"
  }
}

#----------------------------------------------------------------------------
# SNS Topic
#----------------------------------------------------------------------------

# create SNS topic for publishing by ingestion lambda
resource "aws_sns_topic" "tweet_events" {
  # "sentiment-analyzer-dev-tweet-events"
  name         = "${local.name_prefix}-tweet-events"
  display_name = "Tweet Events"
  # AWS-managed encryption at rest
  kms_master_key_id = "alias/aws/sns"

  tags = merge(local.common_tags, {
    Description = "Event distribution topic"
  })
}

# Allow to publish to tweet_events SNS 
# from any Lambda function in this AWS account
resource "aws_sns_topic_policy" "tweet_events" {
  arn = aws_sns_topic.tweet_events.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Human description for this policy
        Sid = "AllowLambdaPublish"
        # Allow vs Deny
        Effect = "Allow"
        # Caller is a Lambda service
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        # Action is to publish to SNS
        Action = "SNS:Publish"
        # Specific SNS being published to
        Resource = aws_sns_topic.tweet_events.arn
        # Caller is this account
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
          }
        }
      }
    ]
  })
}

#----------------------------------------------------------------------------
# SQS Queue
#----------------------------------------------------------------------------
# Dead Letter Queue
resource "aws_sqs_queue" "sentiment_analysis_dlq" {
  name                       = "${local.name_prefix}-sentiment-analysis-dlq"
  message_retention_seconds  = 1209600 # 14 days for investigation
  visibility_timeout_seconds = 600     # 10min for debugging
  receive_wait_time_seconds  = 60      # 60s (longest poll) cheapest

  tags = merge(local.common_tags, {
    Purpose = "Dead letter queue"
  })
}

resource "aws_sqs_queue" "sentiment_analysis" {
  name                       = "${local.name_prefix}-sentiment-analysis"
  delay_seconds              = 0
  max_message_size           = 65536  # 64K (default 256K)
  message_retention_seconds  = 345600 # 4 days
  receive_wait_time_seconds  = 20     # 20s (default 20s)
  visibility_timeout_seconds = 60     # 60s time for Comprehend + DynamoDB

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.sentiment_analysis_dlq.arn
    maxReceiveCount     = 3
  })

  tags = merge(local.common_tags, {
    Purpose = "Sentiment analysis queue"
  })
}

# SQS Queue Policy
# Allow to SendMessage to sentiment analysis SQS
# from any Lambda function in this AWS account
resource "aws_sqs_queue_policy" "sentiment_analysis" {
  queue_url = aws_sqs_queue.sentiment_analysis.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSPublish"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "SQS:SendMessage"
        Resource = aws_sqs_queue.sentiment_analysis.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.tweet_events.arn
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "sqs_target" {
  topic_arn = aws_sns_topic.tweet_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.sentiment_analysis.arn
}

#----------------------------------------------------------------------------
# DynamoDB
#----------------------------------------------------------------------------
resource "aws_dynamodb_table" "tweets" {
  name         = "${local.name_prefix}-tweets"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "tweet_id"
  range_key    = "timestamp"

  attribute {
    name = "tweet_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "sentiment"
    type = "S"
  }

  global_secondary_index {
    name            = "sentiment-index"
    hash_key        = "sentiment"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  ttl {
    attribute_name = "expire_at"
    enabled        = true
  }

  tags = merge(local.common_tags, {
    Purpose = "Tweet storage"
  })
}

#-----------------------------------------------------------------------------
# IAM Role
#-----------------------------------------------------------------------------
resource "aws_iam_role" "lambda_execution" {
  name = "${local.name_prefix}-lambda-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name = "${local.name_prefix}-lambda-permissions"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.tweets.arn,
          "${aws_dynamodb_table.tweets.arn}/index/*"
        ]
      },
      {
        Sid      = "SNSPublish"
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.tweet_events.arn
      },
      {
        Sid      = "ComprehendAccess"
        Effect   = "Allow"
        Action   = ["comprehend:DetectSentiment"]
        Resource = "*"
      },
      {
        Sid    = "SQSAccess"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.sentiment_analysis.arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.ingestion_lambda.arn,
          aws_cloudwatch_log_group.sentiment_lambda.arn,
          "${aws_cloudwatch_log_group.ingestion_lambda.arn}:*",
          "${aws_cloudwatch_log_group.sentiment_lambda.arn}:*"
        ]
      }
    ]
  })

}
#-----------------------------------------------------------------------------
# CloudWatch Log Groups
#-----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "ingestion_lambda" {
  name              = "/aws/lambda/${local.name_prefix}-ingestion"
  retention_in_days = 7
  kms_key_id        = "alias/aws/logs"

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "sentiment_lambda" {
  name              = "/aws/lambda/${local.name_prefix}-sentiment-analysis"
  retention_in_days = 7
  kms_key_id        = "alias/aws/logs"

  tags = local.common_tags
}
