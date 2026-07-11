variable "aws_region" {
  description = "AWS region used for regional resources."
  type        = string
  default     = "us-east-2"
}

variable "website_bucket_name" {
  description = "Globally unique name of the S3 website bucket."
  type        = string
  default     = "jinghanfu-cloud-resume"
}