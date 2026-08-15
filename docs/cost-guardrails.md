# Cost guardrails

## Target

Keep the portfolio MVP at or below **$0.05/day** (about $1.50/month). Review and tear down resources if forecast spend approaches $1.50.

## Low-cost MVP choices

- Small number of sample DICOM studies and small derived assets.
- Serverless orchestration with Lambda, EventBridge, and Step Functions.
- Precomputed demonstration segmentation instead of an always-on ML endpoint.
- Authenticated application or presigned upload instead of a persistent SFTP endpoint.
- No NAT Gateway in the first architecture implementation.
- S3-managed encryption instead of customer-managed KMS keys.
- CloudTrail event history and short-retention CloudWatch logs instead of Security Hub, GuardDuty, Config, or paid audit-data stores.
- Short CloudWatch-log retention and explicit lifecycle rules for demonstration data.

## Known cost traps to avoid

| Service or pattern | Why it is excluded from the MVP |
|---|---|
| AWS Transfer Family SFTP server | It has an always-on endpoint cost; it is not justified for a low-volume demo. |
| Persistent SageMaker endpoint | It charges while running even when no demonstration is taking place. |
| NAT Gateway | It adds a fixed hourly cost without providing enough MVP value. |
| Broad data-event logging with long retention | It can produce a growing log bill without adding portfolio value. |
| Production-scale security features without a cost plan | Enable only the controls demonstrated and monitor their estimates/trials. |
| Security Hub, GuardDuty, AWS Config, or AWS Backup | They may be useful in production but exceed the continuing cost ceiling after trials or as activity grows. |

## Required first deployment controls

1. Create an AWS Budget for $1.50/month with alerts before the ceiling.
2. Tag every created resource with `Project=HealthOps`, `Environment=demo`, `ManagedBy=Terraform`, and `CostCeiling=0.05-USD-per-day`.
3. Set retention/lifecycle policies before uploading sample data.
4. Document a teardown command or runbook for every billable resource.
5. Review Cost Explorer after each major demo exercise.

AWS Budgets alerts are valuable signals, but they are not an instantaneous hard spending cap. Treat the $1.50 monthly ceiling as an active operational control, not a guarantee.
