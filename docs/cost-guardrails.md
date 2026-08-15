# Cost guardrails

## Target

Keep the portfolio MVP at **$0–$10/month**. Review and tear down resources if forecast spend approaches **$20/month**.

## Low-cost MVP choices

- Small number of sample DICOM studies and small derived assets.
- Serverless orchestration with Lambda, EventBridge, and Step Functions.
- Precomputed demonstration segmentation instead of an always-on ML endpoint.
- Authenticated application or presigned upload instead of a persistent SFTP endpoint.
- No NAT Gateway in the first architecture implementation.
- Short CloudWatch-log retention and explicit lifecycle rules for demonstration data.

## Known cost traps to avoid

| Service or pattern | Why it is excluded from the MVP |
|---|---|
| AWS Transfer Family SFTP server | It has an always-on endpoint cost; it is not justified for a low-volume demo. |
| Persistent SageMaker endpoint | It charges while running even when no demonstration is taking place. |
| NAT Gateway | It adds a fixed hourly cost without providing enough MVP value. |
| Broad data-event logging with long retention | It can produce a growing log bill without adding portfolio value. |
| Production-scale security features without a cost plan | Enable only the controls demonstrated and monitor their estimates/trials. |

## Required first deployment controls

1. Create AWS Budgets alerts at $5 and $10.
2. Tag every created resource with `Project=HealthOps`, `Environment=demo`, and `Owner=AndrewBush`.
3. Set retention/lifecycle policies before uploading sample data.
4. Document a teardown command or runbook for every billable resource.
5. Review Cost Explorer after each major demo exercise.

AWS Budgets alerts are valuable signals, but they are not an instantaneous hard spending cap. Treat the $20 ceiling as an active operational control, not a guarantee.
