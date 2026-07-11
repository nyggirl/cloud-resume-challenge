output "website_bucket_name" {
  description = "Name of the S3 bucket hosting the website."
  value       = aws_s3_bucket.website.bucket
}

output "website_endpoint" {
  description = "S3 static website endpoint."
  value       = aws_s3_bucket_website_configuration.website.website_endpoint
}

output "website_url" {
  description = "Public URL for the S3-hosted website."
  value       = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}"
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution."
  value       = aws_cloudfront_distribution.website.id
}

output "cloudfront_domain_name" {
  description = "Domain name assigned to the CloudFront distribution."
  value       = aws_cloudfront_distribution.website.domain_name
}

output "cloudfront_url" {
  description = "HTTPS URL for the CloudFront-hosted website."
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}