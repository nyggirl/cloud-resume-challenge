resource "aws_s3_bucket" "website" {
  bucket = var.website_bucket_name
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"

        Principal = {
          Service = "cloudfront.amazonaws.com"
        }

        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"

        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.website.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  source       = "${path.module}/../frontend/index.html"
  content_type = "text/html"

  etag = filemd5("${path.module}/../frontend/index.html")
}

resource "aws_s3_object" "styles" {
  bucket       = aws_s3_bucket.website.id
  key          = "style.css"
  source       = "${path.module}/../frontend/style.css"
  content_type = "text/css"

  etag = filemd5("${path.module}/../frontend/style.css")
}

resource "aws_s3_object" "script" {
  bucket       = aws_s3_bucket.website.id
  key          = "script.js"
  source       = "${path.module}/../frontend/script.js"
  content_type = "application/javascript"

  etag = filemd5("${path.module}/../frontend/script.js")
}

resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "cloud-resume-oac"
  description                       = "Origin Access Control for the Cloud Resume Challenge"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  default_root_object = "index.html"
  comment             = "Cloud Resume Challenge distribution"
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "s3-cloud-resume-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-cloud-resume-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    allowed_methods = [
      "GET",
      "HEAD"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_dynamodb_table" "visitor_counter" {
  name         = "cloud-resume-visitor-counter"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_execution" {
  name = "cloud-resume-lambda-execution-role"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_dynamodb" {
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:GetItem",
      "dynamodb:UpdateItem"
    ]

    resources = [
      aws_dynamodb_table.visitor_counter.arn
    ]
  }
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "cloud-resume-lambda-dynamodb-policy"
  role = aws_iam_role.lambda_execution.id

  policy = data.aws_iam_policy_document.lambda_dynamodb.json
}

data "archive_file" "lambda_package" {
  type        = "zip"
  source_file = "${path.module}/../backend/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "visitor_counter" {
  function_name = "cloud-resume-visitor-counter"

  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  role    = aws_iam_role.lambda_execution.arn
  handler = "lambda_function.lambda_handler"
  runtime = "python3.13"

  timeout     = 10
  memory_size = 128

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.visitor_counter.name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy.lambda_dynamodb
  ]
}

resource "aws_apigatewayv2_api" "visitor_counter" {
  name          = "cloud-resume-visitor-counter-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET"]
    allow_headers = ["content-type"]
  }
}

resource "aws_apigatewayv2_integration" "visitor_counter" {
  api_id = aws_apigatewayv2_api.visitor_counter.id

  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.visitor_counter.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "visitor_counter" {
  api_id = aws_apigatewayv2_api.visitor_counter.id

  route_key = "GET /visitor-count"
  target    = "integrations/${aws_apigatewayv2_integration.visitor_counter.id}"
}

resource "aws_apigatewayv2_stage" "visitor_counter" {
  api_id = aws_apigatewayv2_api.visitor_counter.id

  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_counter.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.visitor_counter.execution_arn}/*/*"
}