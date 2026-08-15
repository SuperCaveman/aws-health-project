import json
import os
import re

import boto3
from botocore.exceptions import ClientError

s3 = boto3.client("s3")
SAFE_ASSET_ID = re.compile(r"^[A-Za-z0-9._-]+$")


def handler(event, context):
    asset_id = (event.get("pathParameters") or {}).get("assetId", "")
    if not SAFE_ASSET_ID.fullmatch(asset_id):
        return {"statusCode": 400, "body": json.dumps({"message": "Invalid asset identifier"})}

    key = f"approved/{asset_id}"
    try:
        s3.head_object(Bucket=os.environ["DERIVED_BUCKET"], Key=key)
    except ClientError as error:
        if error.response["Error"]["Code"] in {"404", "NoSuchKey", "NotFound"}:
            return {"statusCode": 404, "body": json.dumps({"message": "Approved derived asset not found"})}
        raise

    url = s3.generate_presigned_url(
        "get_object",
        Params={"Bucket": os.environ["DERIVED_BUCKET"], "Key": key},
        ExpiresIn=300,
    )
    return {
        "statusCode": 200,
        "headers": {"content-type": "application/json"},
        "body": json.dumps({"assetId": asset_id, "downloadUrl": url, "expiresInSeconds": 300}),
    }
