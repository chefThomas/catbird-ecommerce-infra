variable "aws_region" {
  description = "The AWS region to deploy the resources"
  default     = "us-east-1"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket to store the terraform state file remotely"
  default     = "catbird-terraform-state"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table to store the terraform state lock"
  default     = "catbird-terraform-state-lock"
}

variable "vpc_name" {
  description = "value of the VPC name"
  default     = "catbird-vpc"
}
