# Architecture decisions

## Customer and business outcome

**Customer:** A healthcare MSP onboarding a specialty medical-imaging customer.

**Outcome:** Replace ungoverned imaging-file handoffs with a repeatable cloud workflow that keeps source clinical data controlled, produces traceable derived 3D assets, and provides operational evidence for every important event.

## Data-flow stages

1. A hospital, imaging site, or vendor submits a DICOM study or related healthcare file through an authenticated intake path.
2. The object lands in an inbound zone and moves through validation, classification, and policy checks.
3. Valid source data is retained in a governed clinical zone. DICOM studies are imported into AWS HealthImaging.
4. HealthImaging import events start a Step Functions workflow using EventBridge.
5. The workflow creates an approved derived output: initially a precomputed segmentation and GLB/STL/OBJ model; later, an on-demand segmentation workload.
6. A visualization client calls the HealthOps API. Authentication and authorization are evaluated before it receives time-limited access to approved derived assets.
7. Intake, policy, processing, and access events are retained as audit evidence.

## Data zones and permissions

| Zone | Purpose | Typical access |
|---|---|---|
| Inbound | Newly received, untrusted files | Intake service writes; validation workflow reads |
| Quarantine | Failed, suspicious, or policy-violating files | Security/operations staff only |
| Clinical source | Controlled source healthcare data | Import and processing roles only |
| Derived | Approved segmentation and transformed outputs | Processing writes; delivery API reads |
| Visualization | Assets approved for the visualization client | Delivery API only; no direct source-data access |
| Audit | Immutable operational and access evidence | Security/audit roles read; services write |
| Archive | Long-lived data governed by retention rules | Lifecycle-managed; restricted access |

## Key decisions

### Preserve the source DICOM study

The DICOM study is the controlled source asset. Derived masks and 3D files are linked through provenance metadata: source study, processing workflow, processing version, timestamp, and approving role. This prevents a display-oriented mesh from being confused with a medical record.

### Separate source and visualization zones

Visualization clients never obtain direct access to source DICOM. They authenticate to an application API, which authorizes a request for an approved derived asset. A policy test deliberately attempts to move source data into the visualization zone and produces a blocked/quarantined event.

### Use event-driven orchestration

EventBridge and Step Functions create a visible, retryable workflow between successful HealthImaging import and derived outputs. The state machine records step-level provenance and supports failed-workflow handling.

### Use an MVP-first security model

The first build uses one dedicated demo account, no real PHI, short data retention, and a low budget. Multi-account separation and a fuller landing zone are production reference-design concerns rather than initial implementation requirements.

## Related life-sciences extension

The architecture can later support a separate clinical-trial data-reconciliation workload. That workload should use CDISC-oriented trial-data structures and controlled human review rather than treating FHIR as a replacement for clinical-trial standards.
