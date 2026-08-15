import json
import os
import urllib.parse
from datetime import datetime, timezone

import boto3

s3 = boto3.client("s3")


def handler(event, context):
    results = []
    for record in event.get("Records", []):
        source_bucket = record["s3"]["bucket"]["name"]
        source_key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])
        header = s3.get_object(Bucket=source_bucket, Key=source_key, Range="bytes=0-131")["Body"].read()
        is_dicom_p10 = source_key.lower().endswith(".dcm") and len(header) >= 132 and header[128:132] == b"DICM"
        destination_bucket = os.environ["CLINICAL_BUCKET"] if is_dicom_p10 else os.environ["QUARANTINE_BUCKET"]
        destination_prefix = "dicom" if is_dicom_p10 else "rejected"
        destination_key = f"{destination_prefix}/{source_key}"
        outcome = "routed-to-clinical" if is_dicom_p10 else "quarantined"

        s3.copy_object(
            Bucket=destination_bucket,
            Key=destination_key,
            CopySource={"Bucket": source_bucket, "Key": source_key},
            ServerSideEncryption="AES256",
        )
        s3.delete_object(Bucket=source_bucket, Key=source_key)

        audit_key = f"intake/{context.aws_request_id}-{len(results)}.json"
        audit_record = {
            "event": "healthops.intake.routed",
            "recordedAt": datetime.now(timezone.utc).isoformat(),
            "outcome": outcome,
            "source": {"bucket": source_bucket, "key": source_key},
            "destination": {"bucket": destination_bucket, "key": destination_key},
            "note": "Demo routing requires a .dcm name and a DICOM P10 DICM marker at byte 128. It is not clinical validation and makes no clinical decision.",
        }
        s3.put_object(
            Bucket=os.environ["AUDIT_BUCKET"],
            Key=audit_key,
            Body=json.dumps(audit_record, indent=2).encode("utf-8"),
            ContentType="application/json",
            ServerSideEncryption="AES256",
        )
        results.append({"outcome": outcome, "auditKey": audit_key, "destinationKey": destination_key})
    return {"results": results}
