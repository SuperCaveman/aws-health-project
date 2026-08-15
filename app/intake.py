import json
import os
import re
import uuid

import boto3

s3 = boto3.client("s3")
SAFE_FILE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,100}\\.dcm$", re.IGNORECASE)


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(body),
    }


def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return response(400, {"message": "Request body must be JSON."})

    file_name = body.get("fileName", "")
    if not SAFE_FILE_NAME.fullmatch(file_name):
        return response(400, {"message": "fileName must be a safe .dcm filename."})

    key = f"uploads/{uuid.uuid4()}-{file_name}"
    upload_url = s3.generate_presigned_url(
        "put_object",
        Params={
            "Bucket": os.environ["INBOUND_BUCKET"],
            "Key": key,
            "ContentType": "application/dicom",
        },
        ExpiresIn=300,
        HttpMethod="PUT",
    )
    return response(200, {"objectKey": key, "uploadUrl": upload_url, "expiresInSeconds": 300})
