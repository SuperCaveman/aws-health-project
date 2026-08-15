# HealthOps security review

**Review date:** 2026-08-15  
**Scope:** The Terraform configuration, Lambda source, GitHub Actions workflow, and the deployed lean MVP in `us-east-1`.

## Verified baseline

- No access keys, passwords, private keys, or application secrets are committed. Terraform state, tfvars files, local environment files, and generated media are ignored.
- All five S3 zones have S3-managed AES-256 default encryption, versioning, and all four S3 public-access-block settings enabled.
- All five S3 zones have a non-public bucket policy that denies every S3 action when `aws:SecureTransport` is `false`.
- All five S3 zones enforce `BucketOwnerEnforced` object ownership. ACL-based ownership cannot be used to bypass the bucket-owner model.
- Lambda and service roles are purpose-scoped: intake presigns only `uploads/*`; routing reads and deletes only inbound objects and writes only its destination/audit prefixes; delivery reads only `derived/approved/*`; Step Functions invokes only the provenance Lambda.
- The API Gateway routes require a Cognito JWT. A live unauthenticated request to the delivery route returned HTTP `401` after this review.
- Cognito requires a 14-character mixed-character password. Optional TOTP MFA is enabled, and token revocation plus user-existence protection are enabled.
- API Gateway has a five-requests-per-second default throttle with a burst of ten. Its seven-day structured access log records request metadata only: request ID, timestamp, route, status, and response length. It does not intentionally log request bodies, tokens, or source IP addresses.
- Lambda log groups retain data for seven days. The project budget remains tagged and alerts at 80% of the $1.50 monthly demo limit.
- CI pins the Terraform-validation actions to immutable Git commit IDs rather than movable major-version tags.

## Controls demonstrated by the application

- Intake accepts only a restricted `.dcm` filename pattern and creates a five-minute presigned upload URL.
- Routing requires the DICOM P10 `DICM` marker at byte 128 before a file enters the clinical-source zone. Other inputs go to quarantine and produce an audit record.
- Import provenance records are written separately to the audit zone. The function does not diagnose, infer, or make a clinical decision.
- Delivery only creates a five-minute presigned URL for an object under the `approved/` prefix.

## Explicit boundaries

This is a low-cost portfolio MVP, not a production healthcare security certification. It has no real patient data and makes no HIPAA-compliance, FDA-clearance, or diagnostic claim. The DICOM marker check is an intake-routing control, not full DICOM conformance validation or malware scanning.

## Production hardening backlog

Before handling production healthcare data, add a signed BAA and eligible AWS-service review; separate AWS accounts and centralized audit storage; customer-managed KMS keys with key policies; organization-wide CloudTrail, AWS Config, GuardDuty, Security Hub, and alerting; private connectivity/VPC endpoints and egress controls; a WAF-protected application edge; full DICOM validation plus malware scanning; mandatory MFA/SSO for privileged users; tested backup, retention, legal-hold, and incident-response procedures; and a formal threat model plus penetration test.
