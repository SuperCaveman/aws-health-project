# Architecture learning map and narration

Read this document beside [`../diagrams/aws-healthops-architecture.mmd`](../diagrams/aws-healthops-architecture.mmd). Each entry maps a colored diagram area to its purpose, the low-cost MVP choice, and the line to use when presenting the architecture.

## 🟠 1. Secure intake

**Diagram nodes:** Authenticated intake, S3 inbound zone, quarantine and validation.

**Learn:**

- [Uploading with S3 presigned URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/using-presigned-url.html)
- [Working with S3 objects](https://docs.aws.amazon.com/AmazonS3/latest/userguide/uploading-downloading-objects.html)

**MVP choice:** Use an authenticated web upload or a tightly scoped presigned S3 URL. Do not operate an always-on Transfer Family SFTP endpoint.

**Narration:** “The workflow starts with authenticated intake. Rather than sharing credentials or exposing a bucket, the platform issues narrowly scoped, time-limited upload access. Every arrival lands in the inbound zone first; it is not trusted clinical data yet.”

## 🟢 2. Governed healthcare data

**Diagram nodes:** Clinical-source zone, AWS HealthImaging, audit and evidence zone.

**Learn:**

- [AWS HealthImaging overview](https://docs.aws.amazon.com/healthimaging/latest/devguide/what-is.html)
- [Importing imaging data with HealthImaging](https://docs.aws.amazon.com/healthimaging/latest/devguide/importing-imaging-data.html)
- [Accessing image sets](https://docs.aws.amazon.com/healthimaging/latest/devguide/accessing-image-sets.html)
- [AWS HealthImaging pricing](https://aws.amazon.com/healthimaging/pricing/)

**MVP choice:** The deployed environment contains no medical study. When a small, appropriately licensed de-identified DICOM study is introduced, the original DICOM remains the controlled source and derived meshes remain separate, traceable outputs.

**Narration:** “After validation, source imaging moves into the governed clinical zone and is imported into HealthImaging. The DICOM study remains the source of truth. It is never treated as interchangeable with a visual mesh produced later in the workflow.”

## 🟣 3. Controlled processing

**Diagram nodes:** EventBridge, Step Functions, segmentation workload, derived-assets zone.

**Learn:**

- [AWS HealthImaging service events in EventBridge](https://docs.aws.amazon.com/eventbridge/latest/ref/events-ref-medical-imaging.html)
- [AWS Step Functions overview](https://docs.aws.amazon.com/step-functions/latest/dg/welcome.html)
- [AWS Lambda overview](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html)

**MVP choice:** Use HealthImaging import completion as the event, then a small Step Functions workflow. Start with a precomputed segmentation/GLB asset; do not run a persistent SageMaker endpoint.

**Narration:** “Import completion emits an event, which starts a visible and retryable workflow. In the first demonstration, the workflow attaches a precomputed, approved derived asset. The architecture is already ready for future on-demand segmentation without paying for idle machine-learning infrastructure.”

## 🟡 4. Controlled delivery

**Diagram nodes:** Cognito and IAM, HealthOps API, web viewer, optional Unreal client.

**Learn:**

- [Using Cognito user pools with API Gateway](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-integrate-with-cognito.html)
- [DICOMweb retrieval from HealthImaging](https://docs.aws.amazon.com/healthimaging/latest/devguide/dicomweb-retrieve.html)
- [HealthImaging image frame decoding and viewer integrations](https://docs.aws.amazon.com/healthimaging/latest/devguide/reference-libraries.html)

**MVP choice:** Deliver approved GLB assets through a browser-based viewer/API. Unreal is an optional consumer, not a backend dependency. Do not give any viewer direct access to source DICOM.

**Narration:** “The viewer asks the HealthOps API for an approved derived asset. Cognito authenticates the user and the API applies authorization before returning a time-limited response. The architectural boundary is deliberate: a visualization client can see the approved mesh, but it cannot browse original clinical imaging.”

## 🔵 Control plane

**Diagram nodes:** Terraform and CI/CD, S3-managed encryption/IAM policies, CloudTrail/CloudWatch controls, lifecycle rules, and budgets.

**Learn:**

- [AWS IAM documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/introduction.html)
- [Amazon S3 encryption guide](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingServerSideEncryption.html)
- [AWS CloudTrail documentation](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-user-guide.html)
- [Amazon CloudWatch documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/WhatIsCloudWatch.html)
- [Creating an AWS cost budget](https://docs.aws.amazon.com/cost-management/latest/userguide/create-cost-budget.html)

**MVP choice:** Begin with Terraform, encryption, least-privilege roles, CloudTrail, short log retention, tags, and budget alerts. Enable costly or production-scale security features only when they contribute to a recorded demo.

**Narration:** “The controls are not an afterthought. Terraform makes the environment repeatable; S3-managed encryption and IAM constrain access; CloudTrail and CloudWatch provide evidence of what happened. Budgets and lifecycle rules keep the portfolio environment intentionally cheap.”

## Full architecture narration

“AWS HealthOps solves a governed healthcare-data movement problem. A hospital or imaging partner submits a study through an authenticated intake path. The file is validated and classified before it enters the controlled clinical-data zone. DICOM imaging is organized in AWS HealthImaging, where import events trigger a Step Functions workflow. That workflow creates a traceable derived output while preserving the original DICOM study as the clinical source of truth. An authorized user accesses the approved derived asset through a secure API and viewer; the viewer never receives broad access to source imaging. Across every stage, Terraform, encryption, least privilege, audit logging, monitoring, and budgets make the environment repeatable, observable, and inexpensive to operate.”

## Demo control proof

The key test to record is a denied or quarantined attempt to send a source-DICOM object to the visualization zone. The architecture’s value is not merely that it moves a file—it proves that different data classes have different permissions, destinations, and audit evidence.
