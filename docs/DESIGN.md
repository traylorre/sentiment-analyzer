# Sentiment Analyzer - Design Document

## Status
🚧 **Phase 1: Proof of Concept** - Validating AWS service integration

## 1. Overview

Real-time sentiment analysis pipeline for Twitter-like data using AWS serverless services.

**Goal:** Architect and implement event-driven systems on AWS.

---

## 2. Requirements

### Functional
- [ ] Ingest tweet data (tweet_id, text, user_id, timestamp)
- [ ] Analyze sentiment using AWS Comprehend
- [ ] Store results in DynamoDB with queryable sentiment index
- [ ] Handle failures gracefully (DLQ, retries)

### Non-Functional
- **Scale:** Support ~1,000 tweets/sec (portfolio project scale)
- **Latency:** <5 seconds end-to-end
- **Cost:** <$50/month for moderate usage (excluding feed cost)
- **Availability:** Best-effort (not mission-critical)

### Out of Scope (Phase 1)
- Public API endpoint (dev only for now)
- Real-time dashboard
- Historical trend analysis
- Custom ML models

---

## 3. Architecture

```
┌─────────────┐      ┌─────────┐      ┌─────────┐      ┌──────────────┐      ┌──────────┐
│  Ingestion  │─────>│   SNS   │─────>│   SQS   │─────>│   Analysis   │─────>│ DynamoDB │
│   Lambda    │      │  Topic  │      │  Queue  │      │    Lambda    │      │  Table   │
└─────────────┘      └─────────┘      └─────────┘      └──────────────┘      └──────────┘
                                            │                   │
                                            │                   ▼
                                            │            ┌──────────────┐
                                            │            │ Comprehend   │
                                            │            │     API      │
                                            │            └──────────────┘
                                            ▼
                                       ┌─────────┐
                                       │   DLQ   │
                                       └─────────┘
```

**Data Flow:**
1. Ingestion Lambda receives tweet → validates → publishes to SNS
2. SNS fans out to SQS queue (horizontal scaling)
3. SQS triggers Analysis Lambda (batched)
4. Analysis Lambda calls Comprehend → writes to DynamoDB
5. Failed messages (after 3 retries) → DLQ for investigation

---

## 4. Component Design

### 4.1 Ingestion Lambda
- **Runtime:** Python 3.11
- **Timeout:** 10s
- **Memory:** 128MB (minimal, just validation + SNS publish)
- **Permissions:** SNS:Publish, CloudWatch Logs
- **Error Handling:** Returns 400 for invalid input, 500 for SNS failures

### 4.2 SNS Topic
- **Purpose:** Decouple ingestion from downstream processing
- **Encryption:** AWS-managed KMS key

### 4.3 SQS Queue
- **Visibility Timeout:** 60s (matches Lambda timeout)
- **Message Retention:** 4 days
- **Max Receive Count:** 3 (then → DLQ)
- **Long Polling:** 20s (cost optimization)
- **Why SQS:** Buffers messages, handles Comprehend rate limits, enables batching

### 4.4 Analysis Lambda
- **Runtime:** Python 3.11
- **Timeout:** 60s (Comprehend call + DynamoDB write)
- **Memory:** 256MB
- **Batch Size:** 10 messages (TODO: tune based on testing)
- **Permissions:** SQS, Comprehend, DynamoDB, CloudWatch Logs

### 4.5 DynamoDB Table
- **Primary Key:** tweet_id (String)
- **Sort Key:** timestamp (Number)
- **GSI:** sentiment-index (sentiment + timestamp)
- **Billing:** PAY_PER_REQUEST (unpredictable traffic)
- **TTL:** expire_at (90 days retention)
- **Encryption:** AWS-managed

---

## 5. Key Design Decisions

| Decision | Choice | Alternative Considered | Rationale | When to Reconsider |
|----------|--------|----------------------|-----------|-------------------|
| **Message Queue** | SQS Standard | Kinesis Data Streams | <1K msg/sec, simpler ops, lower cost | >10K msg/sec or need replay capability |
| **Pub/Sub** | SNS + SQS | Direct SQS | Fan-out capability for future consumers | If only ever 1 consumer, direct SQS simpler |
| **Database** | DynamoDB | RDS PostgreSQL | Serverless, key-value access pattern, no ops | Need complex joins or transactions |
| **Sentiment Analysis** | AWS Comprehend | Custom ML (SageMaker) | Fast to implement, good accuracy, no training | Need domain-specific sentiment (e.g., financial) |
| **Compute** | Lambda | ECS/Fargate | Event-driven, auto-scaling, pay-per-use | Long-running processes or need GPU |
| **IaC** | Terraform | CloudFormation/CDK | Multi-cloud skills, HCL readability | AWS-only shop prefers CDK |

---

## 6. Failure Modes & Mitigation

| Failure Scenario | Impact | Detection | Mitigation | Recovery |
|-----------------|--------|-----------|------------|----------|
| **Comprehend throttle** | Analysis delayed | CloudWatch metrics | SQS retry with backoff | Automatic (SQS redelivery) |
| **DynamoDB throttle** | Write fails | Lambda errors | Exponential backoff in code | Retry from SQS |
| **Lambda timeout** | Message not processed | CloudWatch alarms | Increase timeout or reduce batch size | SQS redelivery (up to 3x) |
| **Malformed tweet** | Poison message | Validation errors | Input validation + DLQ after 3 retries | Manual investigation of DLQ |
| **SNS publish fails** | Tweet not ingested | 500 response to caller | Retry at client | Caller responsibility |
| **Lambda cold start** | Higher latency | X-Ray traces | Provisioned concurrency (if needed) | Accept for POC |

---

## 7. Observability

### Metrics (CloudWatch)
- SQS: `ApproximateNumberOfMessagesVisible` (queue depth)
- Lambda: `Errors`, `Duration`, `Throttles`
- DynamoDB: `UserErrors`, `SystemErrors`

### Logs (CloudWatch Logs)
- Structured JSON with correlation IDs (tweet_id)
- Retention: 7 days (cost optimization)

### Alarms (Phase 2)
- DLQ depth > 10 messages
- Lambda error rate > 5%
- SQS queue depth > 1000 (backlog building)

### Dashboards (Phase 2)
- End-to-end latency
- Throughput (tweets/min)
- Error rates by component

### Custom Metrics (Phase 3)
- Sentiment distribution (positive/negative/neutral/mixed)
- Sentiment by keyword/topic

---

## 8. Cost Estimate (1M tweets/month)

| Service | Usage | Cost |
|---------|-------|------|
| Lambda (Ingestion) | 1M invocations × 128MB × 100ms | $0.20 |
| Lambda (Analysis) | 1M invocations × 256MB × 1s | $3.33 |
| SNS | 1M publishes | $0.50 |
| SQS | 1M requests | $0.40 |
| DynamoDB | 1M writes + 100K reads | $1.50 |
| Comprehend | 1M units (100 chars avg) | $100.00 |
| CloudWatch Logs | 5GB | $2.50 |
| **Total** | | **~$108/month** |

**Cost driver:** Comprehend (92% of cost). At scale, consider batching or custom models.

---

## 9. Testing Strategy

### Unit Tests (pytest + moto)
- Lambda handler logic (validation, error handling)
- Mock AWS SDK calls
- Fast (<1s), no AWS credentials needed

### Integration Tests (moto)
- SNS → SQS message flow
- Message format validation
- End-to-end with mocked AWS

### Manual Testing (dev environment)
- Deploy to AWS dev account
- Send sample tweets
- Verify DynamoDB writes
- Check CloudWatch logs

---

## 10. Future Work

### Phase 2: Monitoring & Alerting (MVP)

**Goal:** Production-ready observability

- [ ] CloudWatch alarms (DLQ depth, Lambda errors, SQS backlog)
- [ ] CloudWatch dashboard (latency, throughput, error rates)
- [ ] SNS alerts for critical failures (email/Slack)

### Phase 3: Demo-Ready

**Goal:** Enhanced metrics and public access

- [ ] API Gateway for public ingestion endpoint
- [ ] Custom CloudWatch metrics (sentiment distribution, sentiment by keyword)
- [ ] DynamoDB Streams → Aggregator Lambda
- [ ] Keyword extraction (string matching or Comprehend)
- [ ] Enhanced dashboard with sentiment trends

### Phase 4+

**Goal:** Business Intelligence

- [ ] Sentiment trend analysis (Athena + QuickSight)
- [ ] Multi-region deployment
- [ ] Cost optimization (Reserved Capacity if traffic predictable)

### Open Ideas

### Open Ideas (Future Exploration)

**Real-Time Alerting**
- [ ] Keyword-based alerts ("AWS Lambda" + NEGATIVE > threshold → Slack notification)
- [ ] Trending topics detection (spike in keyword mentions)
- [ ] Sentiment shift alerts (sudden drop in positivity for tracked topics)

**Advanced Search**
- [ ] Full-text search (OpenSearch for complex queries)
- [ ] Saved watchlists (monitor specific keywords/users)

**Analytics & ML**
- [ ] Sentiment trends over time (hourly/daily aggregates)
- [ ] Keyword co-occurrence analysis (what topics appear together)
- [ ] Custom ML model for domain-specific sentiment (financial, healthcare)
---

## 11. Open Questions
- **Hot table primary key** Tweet Events table has hot GSI (low spread), can we do better?
- **Exactly-once vs at-least-once?** Do we need idempotency/deduplication?
- **Data retention?** 90-day TTL sufficient?
- **Batch size tuning?** Start with 10, but what's optimal for Comprehend throughput?
- **Error notification?** Should DLQ trigger SNS alert to ops team?

---

## References

- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [SNS Message Structure](https://docs.aws.amazon.com/sns/latest/dg/sns-message-and-json-formats.html)
- [SQS Best Practices](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-best-practices.html)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [Comprehend Pricing](https://aws.amazon.com/comprehend/pricing/)
