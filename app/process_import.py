import json
import os
from datetime import datetime, timezone

import boto3

s3 = boto3.client("s3")


def handler(event, context):
    detail = event.get("detail", {})
    job_id = detail.get("jobId", context.aws_request_id)
    record = {
        "event": "healthops.import.provenance.recorded",
        "jobId": job_id,
        "recordedAt": datetime.now(timezone.utc).isoformat(),
        "sourceEvent": event,
        "note": "Demo provenance record. No clinical decision or diagnosis is performed.",
    }
    key = f"provenance/{job_id}.json"
    s3.put_object(
        Bucket=os.environ["AUDIT_BUCKET"],
        Key=key,
        Body=json.dumps(record, indent=2, default=str).encode("utf-8"),
        ContentType="application/json",
        ServerSideEncryption="AES256",
    )
    return {"status": "recorded", "auditKey": key, "jobId": job_id}
