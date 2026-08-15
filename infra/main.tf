data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  name_prefix = "${var.project_name}-${local.account_id}-${var.aws_region}"
  common_tags = {
    Project     = "HealthOps"
    Environment = "demo"
    ManagedBy   = "Terraform"
    CostCeiling = "0.05-USD-per-day"
  }

  bucket_names = {
    inbound    = "${local.name_prefix}-inbound"
    quarantine = "${local.name_prefix}-quarantine"
    clinical   = "${local.name_prefix}-clinical"
    derived    = "${local.name_prefix}-derived"
    audit      = "${local.name_prefix}-audit"
  }
}

resource "aws_s3_bucket" "zone" {
  for_each      = local.bucket_names
  bucket        = each.value
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "zone" {
  for_each = aws_s3_bucket.zone
  bucket   = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "zone" {
  for_each = aws_s3_bucket.zone
  bucket   = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "zone" {
  for_each = aws_s3_bucket.zone
  bucket   = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "zone" {
  for_each = aws_s3_bucket.zone
  bucket   = each.value.id

  rule {
    id     = "demo-retention"
    status = "Enabled"

    filter {}

    expiration {
      days = each.key == "clinical" ? 31 : 14
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

resource "aws_s3_object" "derived_placeholder" {
  bucket                 = aws_s3_bucket.zone["derived"].id
  key                    = "approved/README.txt"
  content                = "HealthOps derived-assets zone. This placeholder is not clinical data or a medical image."
  content_type           = "text/plain"
  server_side_encryption = "AES256"
}

resource "aws_iam_role" "healthimaging_import" {
  name = "${var.project_name}-healthimaging-import"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "medical-imaging.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "healthimaging_import" {
  name = "${var.project_name}-healthimaging-import"
  role = aws_iam_role.healthimaging_import.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [aws_s3_bucket.zone["clinical"].arn, aws_s3_bucket.zone["audit"].arn]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["${aws_s3_bucket.zone["clinical"].arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["${aws_s3_bucket.zone["audit"].arn}/*"]
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "processing" {
  name              = "/aws/lambda/${var.project_name}-process-import"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "delivery" {
  name              = "/aws/lambda/${var.project_name}-delivery"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "intake" {
  name              = "/aws/lambda/${var.project_name}-intake"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "validate_intake" {
  name              = "/aws/lambda/${var.project_name}-validate-intake"
  retention_in_days = 7
}

resource "aws_iam_role" "process_lambda" {
  name = "${var.project_name}-process-import-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "process_lambda_logs" {
  role       = aws_iam_role.process_lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "process_lambda_audit" {
  name = "${var.project_name}-write-audit"
  role = aws_iam_role.process_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = ["${aws_s3_bucket.zone["audit"].arn}/provenance/*"]
    }]
  })
}

resource "aws_iam_role" "delivery_lambda" {
  name = "${var.project_name}-delivery-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "delivery_lambda_logs" {
  role       = aws_iam_role.delivery_lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "delivery_lambda_read_derived" {
  name = "${var.project_name}-read-approved-derived"
  role = aws_iam_role.delivery_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = ["${aws_s3_bucket.zone["derived"].arn}/approved/*"]
    }]
  })
}

resource "aws_iam_role" "intake_lambda" {
  name = "${var.project_name}-intake-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "intake_lambda_logs" {
  role       = aws_iam_role.intake_lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "intake_lambda_presign" {
  name = "${var.project_name}-presign-inbound-upload"
  role = aws_iam_role.intake_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = ["${aws_s3_bucket.zone["inbound"].arn}/uploads/*"]
    }]
  })
}

resource "aws_iam_role" "validate_intake_lambda" {
  name = "${var.project_name}-validate-intake-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "validate_intake_lambda_logs" {
  role       = aws_iam_role.validate_intake_lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "validate_intake_lambda_data_zones" {
  name = "${var.project_name}-route-intake-data"
  role = aws_iam_role.validate_intake_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:DeleteObject"]
        Resource = ["${aws_s3_bucket.zone["inbound"].arn}/uploads/*"]
      },
      {
        Effect = "Allow"
        Action = ["s3:PutObject"]
        Resource = [
          "${aws_s3_bucket.zone["clinical"].arn}/dicom/*",
          "${aws_s3_bucket.zone["quarantine"].arn}/rejected/*",
          "${aws_s3_bucket.zone["audit"].arn}/intake/*",
        ]
      },
    ]
  })
}

resource "aws_lambda_function" "process_import" {
  function_name    = "${var.project_name}-process-import"
  role             = aws_iam_role.process_lambda.arn
  handler          = "process_import.handler"
  runtime          = "python3.12"
  filename         = "${path.module}/artifacts/process-import.zip"
  source_code_hash = filebase64sha256("${path.module}/artifacts/process-import.zip")
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      AUDIT_BUCKET = aws_s3_bucket.zone["audit"].id
    }
  }

  depends_on = [aws_cloudwatch_log_group.processing]
}

resource "aws_lambda_function" "delivery" {
  function_name    = "${var.project_name}-delivery"
  role             = aws_iam_role.delivery_lambda.arn
  handler          = "delivery.handler"
  runtime          = "python3.12"
  filename         = "${path.module}/artifacts/delivery.zip"
  source_code_hash = filebase64sha256("${path.module}/artifacts/delivery.zip")
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      DERIVED_BUCKET = aws_s3_bucket.zone["derived"].id
    }
  }

  depends_on = [aws_cloudwatch_log_group.delivery]
}

resource "aws_lambda_function" "intake" {
  function_name    = "${var.project_name}-intake"
  role             = aws_iam_role.intake_lambda.arn
  handler          = "intake.handler"
  runtime          = "python3.12"
  filename         = "${path.module}/artifacts/intake.zip"
  source_code_hash = filebase64sha256("${path.module}/artifacts/intake.zip")
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      INBOUND_BUCKET = aws_s3_bucket.zone["inbound"].id
    }
  }

  depends_on = [aws_cloudwatch_log_group.intake]
}

resource "aws_lambda_function" "validate_intake" {
  function_name    = "${var.project_name}-validate-intake"
  role             = aws_iam_role.validate_intake_lambda.arn
  handler          = "validate_intake.handler"
  runtime          = "python3.12"
  filename         = "${path.module}/artifacts/validate-intake.zip"
  source_code_hash = filebase64sha256("${path.module}/artifacts/validate-intake.zip")
  timeout          = 15
  memory_size      = 128

  environment {
    variables = {
      AUDIT_BUCKET      = aws_s3_bucket.zone["audit"].id
      CLINICAL_BUCKET   = aws_s3_bucket.zone["clinical"].id
      QUARANTINE_BUCKET = aws_s3_bucket.zone["quarantine"].id
    }
  }

  depends_on = [aws_cloudwatch_log_group.validate_intake]
}

resource "aws_lambda_permission" "s3_invoke_validate_intake" {
  statement_id  = "AllowS3InboundInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.validate_intake.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.zone["inbound"].arn
}

resource "aws_s3_bucket_notification" "inbound" {
  bucket = aws_s3_bucket.zone["inbound"].id

  lambda_function {
    lambda_function_arn = aws_lambda_function.validate_intake.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
  }

  depends_on = [aws_lambda_permission.s3_invoke_validate_intake]
}

resource "aws_iam_role" "step_functions" {
  name = "${var.project_name}-step-functions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "step_functions_invoke" {
  name = "${var.project_name}-invoke-process-import"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = [aws_lambda_function.process_import.arn]
    }]
  })
}

resource "aws_sfn_state_machine" "processing" {
  name     = "${var.project_name}-processing"
  role_arn = aws_iam_role.step_functions.arn
  type     = "STANDARD"

  definition = jsonencode({
    Comment = "HealthOps import provenance workflow"
    StartAt = "RecordProvenance"
    States = {
      RecordProvenance = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.process_import.arn
          "Payload.$"  = "$"
        }
        OutputPath = "$.Payload"
        Next       = "Completed"
      }
      Completed = { Type = "Succeed" }
    }
  })
}

resource "aws_iam_role" "eventbridge_start_workflow" {
  name = "${var.project_name}-eventbridge-start-workflow"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge_start_workflow" {
  name = "${var.project_name}-start-processing"
  role = aws_iam_role.eventbridge_start_workflow.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["states:StartExecution"]
      Resource = [aws_sfn_state_machine.processing.arn]
    }]
  })
}

resource "aws_cloudwatch_event_rule" "healthimaging_import_complete" {
  name        = "${var.project_name}-healthimaging-import-complete"
  description = "Starts the provenance workflow after a HealthImaging import completes."

  event_pattern = jsonencode({
    source        = ["aws.medical-imaging"]
    "detail-type" = ["Import Job Completed"]
  })
}

resource "aws_cloudwatch_event_target" "healthimaging_import_complete" {
  rule      = aws_cloudwatch_event_rule.healthimaging_import_complete.name
  target_id = "StartHealthOpsProcessing"
  arn       = aws_sfn_state_machine.processing.arn
  role_arn  = aws_iam_role.eventbridge_start_workflow.arn
}

resource "aws_cognito_user_pool" "viewer" {
  name                     = "${var.project_name}-viewer"
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 14
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }
}

resource "aws_cognito_user_pool_client" "viewer" {
  name                                 = "${var.project_name}-viewer-client"
  user_pool_id                         = aws_cognito_user_pool.viewer.id
  generate_secret                      = false
  explicit_auth_flows                  = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  prevent_user_existence_errors        = "ENABLED"
  enable_token_revocation              = true
  allowed_oauth_flows_user_pool_client = false
}

resource "aws_apigatewayv2_api" "delivery" {
  name          = "${var.project_name}-delivery"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "delivery" {
  api_id                 = aws_apigatewayv2_api.delivery.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.delivery.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "intake" {
  api_id                 = aws_apigatewayv2_api.delivery.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.intake.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_authorizer" "viewer" {
  api_id           = aws_apigatewayv2_api.delivery.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${var.project_name}-viewer-jwt"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.viewer.id]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.viewer.id}"
  }
}

resource "aws_apigatewayv2_route" "delivery" {
  api_id             = aws_apigatewayv2_api.delivery.id
  route_key          = "GET /derived/{assetId}"
  target             = "integrations/${aws_apigatewayv2_integration.delivery.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.viewer.id
}

resource "aws_apigatewayv2_route" "intake" {
  api_id             = aws_apigatewayv2_api.delivery.id
  route_key          = "POST /intake/upload-url"
  target             = "integrations/${aws_apigatewayv2_integration.intake.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.viewer.id
}

resource "aws_apigatewayv2_stage" "delivery" {
  api_id      = aws_apigatewayv2_api.delivery.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway_delivery" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delivery.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.delivery.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gateway_intake" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.intake.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.delivery.execution_arn}/*/*"
}

resource "aws_budgets_budget" "healthops" {
  name         = "${var.project_name}-monthly-1-50"
  budget_type  = "COST"
  limit_amount = "1.50"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Project$HealthOps"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }
}
