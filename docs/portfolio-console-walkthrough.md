# Portfolio console walkthrough and video narration

This public guide maps the architecture to AWS services without publishing any live account IDs, resource names, endpoints, or console deep links. In a real deployment, open each named service in the selected AWS Region and find the resource by its project tag.

## 1. Secure intake

- **Amazon Cognito and Amazon API Gateway:** “The intake path is not a public file share. Cognito authenticates the partner and API Gateway verifies the JWT before the platform creates a narrow upload link.”
- **Intake Lambda and Amazon S3 inbound zone:** “The intake function creates a five-minute upload URL for one permitted DICOM object. Every arrival starts in an untrusted inbound zone.”
- **Routing Lambda and S3 quarantine zone:** “The routing control requires a safe `.dcm` filename and the DICOM P10 marker. Failed inputs are isolated in quarantine rather than entering the clinical-data zone.”

## 2. Governed healthcare data

- **S3 clinical-source zone:** “Valid inputs enter a separate clinical-source zone with encryption, versioning, lifecycle limits, and public access blocked.”
- **AWS HealthImaging:** “A permitted, de-identified study can be organized in AWS HealthImaging while the original DICOM remains the clinical source of truth.”
- **S3 audit/evidence zone:** “Routing evidence and provenance records are treated as first-class workflow outputs.”

## 3. Event-driven provenance

- **Amazon EventBridge:** “A completed HealthImaging import emits an event, separating the imaging service from downstream workflow handling.”
- **AWS Step Functions:** “Step Functions makes the provenance workflow visible and traceable rather than hiding it in a background script.”
- **Provenance Lambda:** “The Lambda records the import job ID, time, and source event. It makes no inference, diagnosis, or clinical decision.”

## 4. Controlled delivery

- **S3 derived-assets zone and delivery Lambda:** “Approved derived assets are stored separately from clinical source imaging. The delivery function creates a short-lived URL only after JWT authorization.”
- **Future OHIF/Cornerstone3D portal:** “Clinicians would use a familiar browser workflow, not the AWS Console. The viewer receives only approved content and is not the system of record.”

## 5. Cross-cutting controls

- **Terraform and CI:** “The design is reproducible and reviewable as code.”
- **IAM, S3, CloudWatch, CloudTrail, and AWS Budgets:** “Least privilege, encryption, auditability, short log retention, and an explicit cost boundary are designed into the MVP.”

## Demonstration boundaries

This portfolio MVP has no real patient data, makes no diagnostic decision, and does not claim HIPAA compliance or FDA clearance. A private operator runbook exists separately for the deployed account; it is intentionally excluded from this public repository.
