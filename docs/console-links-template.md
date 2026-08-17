# Live AWS console map and video narration

**Account:** `<AWS_ACCOUNT_ID>`
**Region:** `us-east-1`
**Scope:** deployed lean MVP; no real healthcare data or de-identified medical images are stored.
**Architecture:** [`../diagrams/aws-healthops-architecture.mmd`](../diagrams/aws-healthops-architecture.mmd)

This file is a **template**. It intentionally omits account-specific identifiers (account ID, Cognito pool/client IDs, API Gateway ID, HealthImaging datastore ID). The real, filled-in version is kept locally as an operator runbook at `docs/live-aws-console-links.md`, which is gitignored and never committed.

Open these links while signed in to your own AWS account. They correspond directly to the colored areas in the diagram.

## 1. Secure intake

| Diagram node | Live resource | What to say in the video |
|---|---|---|
| Cognito JWT | HealthOps viewer user pool (Cognito console → User pools → `healthops-viewer`) | "The intake path is not a public file share. Cognito issues the JWT that API Gateway verifies before the platform creates an upload URL." |
| HealthOps API | HTTP API routes (API Gateway console → APIs → `healthops-delivery`) | "This API has two protected routes: one creates a five-minute upload URL, and the other gives an authorized user a short-lived download for an approved derived asset." |
| Intake Lambda | `healthops-intake` (Lambda console) | "The intake function accepts only a safe `.dcm` file name and signs a narrow, five-minute S3 PUT—not an AWS credential or open bucket permission." |
| S3 inbound zone | `healthops-<account-id>-us-east-1-inbound` (S3 console) | "Every arrival lands in an inbound zone first. It is untrusted until the routing control evaluates it." |
| Routing Lambda | `healthops-validate-intake` (Lambda console) | "This control requires both a `.dcm` name and the DICOM P10 `DICM` marker at byte 128. It is an intake-routing check, not a diagnosis or full clinical validation." |
| Quarantine zone | `healthops-<account-id>-us-east-1-quarantine` (S3 console) | "Inputs that fail the routing check are isolated instead of flowing into the clinical zone." |

## 2. Governed healthcare data

| Diagram node | Live resource | What to say in the video |
|---|---|---|
| Clinical-source zone | `healthops-<account-id>-us-east-1-clinical` (S3 console) | "Valid DICOM P10 objects are placed in a distinct clinical-source zone, with encryption, versioning, lifecycle limits, and no public access." |
| AWS HealthImaging | `healthops-clinical-imaging` datastore (HealthImaging console) | "HealthImaging is where a permitted DICOM study is organized as imaging data. The datastore is live but deliberately empty until I add an appropriately licensed, de-identified sample." |
| Audit / evidence zone | `healthops-<account-id>-us-east-1-audit` (S3 console) | "The system writes routing evidence and processing provenance here. Evidence is a first-class output, not an afterthought." |

## 3. Event-driven provenance

| Diagram node | Live resource | What to say in the video |
|---|---|---|
| EventBridge | `healthops-healthimaging-import-complete` rule (EventBridge console) | "A completed HealthImaging import emits an event. EventBridge decouples the imaging service from the workflow that handles provenance." |
| Step Functions | `healthops-processing` state machine (Step Functions console) | "Step Functions gives operations a visible, retryable workflow instead of an opaque background script." |
| Provenance Lambda | `healthops-process-import` (Lambda console) | "This small function writes a provenance record for the import event. It performs no inference, no diagnosis, and no clinical decision." |
| Future segmentation | No resource is running | "Segmentation and 3D creation are intentionally future, on-demand work. I avoided an always-on ML endpoint because it would break the cost target." |

## 4. Controlled delivery

| Diagram node | Live resource | What to say in the video |
|---|---|---|
| Derived-assets zone | `healthops-<account-id>-us-east-1-derived` (S3 console) | "Approved derived outputs live separately from the clinical source. The current README object is only a harmless wiring placeholder, not a medical asset." |
| Delivery Lambda | `healthops-delivery` (Lambda console) | "The delivery function can read only the `approved/` prefix. It returns a five-minute download URL only after API Gateway has verified a Cognito JWT." |
| Viewer | Future web or Unreal client | "The viewer is a consumer, not a trusted data store. It receives an approved derived asset and never broad access to source DICOM." |

## 5. Cross-cutting controls

| Diagram node | Live resource | What to say in the video |
|---|---|---|
| Terraform | [`../infra`](../infra) and [GitHub Actions workflow](../.github/workflows/terraform.yml) | "Terraform makes the design reproducible: zones, IAM, API routes, event wiring, logs, and the budget can be reviewed as code." |
| Least-privilege HealthImaging role | `healthops-healthimaging-import` (IAM console → Roles) | "The imaging import service has a narrowly scoped role: it reads the clinical zone and writes import output to the audit zone." |
| CloudWatch | `/aws/lambda/healthops-validate-intake` log group (CloudWatch console) | "CloudWatch gives the operator execution-level troubleshooting evidence, with a seven-day retention limit for the portfolio environment." |
| CloudTrail event history | Event history (CloudTrail console) | "CloudTrail event history shows which AWS identity changed or accessed control-plane resources. It is useful operational evidence, but it is not a substitute for a full production audit design." |
| Budget | AWS Budgets — `healthops-monthly-1-50` | "This budget is filtered to `Project=HealthOps`, alerts at 80% of $1.50 per month, and makes the demo's cost boundary explicit. Alerts are not instantaneous hard stops." |

## Verified proof points to record

1. **Policy enforcement:** a harmless README uploaded as `uploads/demo-fake-scan.dcm` did **not** contain the DICOM P10 marker. The routing Lambda quarantined it at `rejected/uploads/demo-fake-scan.dcm`, removed it from inbound, and wrote an audit record to the audit bucket.
2. **Workflow:** a synthetic no-PHI event completed successfully in `healthops-processing` and wrote a provenance record to the audit bucket.
3. **Access control:** without a JWT, both `POST /intake/upload-url` and `GET /derived/{assetId}` returned HTTP `401`.
4. **Data-zone baseline:** all five project buckets were verified with S3-managed AES-256 encryption, versioning enabled, and public-access blocking enabled.

## Short walkthrough narration

"AWS HealthOps solves a controlled healthcare imaging-exchange problem for an MSP onboarding a specialty imaging customer. A partner authenticates with Cognito and asks the HealthOps API for a narrow, five-minute upload URL. The object arrives in an inbound zone, where a routing Lambda requires both a `.dcm` name and the DICOM P10 marker before it can enter the clinical-source zone. Failed inputs are quarantined, with evidence written to the audit zone. When an approved de-identified study is imported into AWS HealthImaging, EventBridge starts a Step Functions workflow that records provenance. Source DICOM and visual assets stay separated. An authenticated viewer can request only an approved derived asset through the API, never broad access to clinical imaging. Terraform, least-privilege IAM, encryption, logs, event history, lifecycle limits, and a project-tagged budget make the solution repeatable and intentionally inexpensive."

## What remains intentionally future

- Create a Cognito demo user to exercise a successful authenticated upload and download.
- Add a properly licensed, de-identified DICOM P10 study, run `StartDICOMImportJob`, and record the automatic EventBridge trigger.
- Add an on-demand segmentation job and a GLB/STL/SEG output only when it has a clear portfolio purpose and a reviewed cost estimate.

## Filling in your own copy

Copy this template to `docs/live-aws-console-links.md`, fill in your account ID and resource IDs, and leave it in place — that filename is gitignored, so the real, account-specific version never gets committed.
