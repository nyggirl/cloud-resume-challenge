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