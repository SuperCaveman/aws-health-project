# Portfolio video storyboard

## Goal

Create a 3–5 minute LinkedIn/portfolio video that tells an architect's story: customer problem, controlled cloud design, proof of policy enforcement, and outcome.

## Narrative

1. **Problem (0:00–0:25):** Healthcare imaging teams need to transform and deliver derived 3D outputs without exposing source clinical imaging or losing traceability.
2. **Architecture (0:25–0:50):** Show the HealthOps diagram and explain the zones, the event-driven path, and the separation between source DICOM and visual assets.
3. **Successful intake (0:50–1:35):** Submit a synthetic/de-identified DICOM study; show validation, classification, source storage, and HealthImaging import.
4. **Processing and provenance (1:35–2:10):** Show the workflow producing a derived asset and the record linking it to the source study and processing version.
5. **Controlled delivery (2:10–2:40):** Show an authorized viewer retrieving the derived model through the application API. The viewer has no direct source-DICOM access.
6. **Policy enforcement (2:40–3:10):** Attempt to send source DICOM to the visualization zone; show the block/quarantine event and audit evidence.
7. **Outcome and roadmap (3:10–3:30):** Summarize repeatable onboarding, governance, auditability, and the planned clinical-trial data extension.

## Recording checkpoints

Record short clips as they become available:

- Successful secure intake and validated placement.
- The denied/quarantined source-data transfer (the strongest control proof).
- Derived 3D asset authorization and viewer delivery.
- Audit timeline, dashboard, or workflow-recovery proof.

Do not wait until the complete build to start recording; capture each verified milestone while its environment and evidence are available.
