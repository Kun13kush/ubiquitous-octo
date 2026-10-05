terraform {
  required_version = ">= 1.10, < 2.0"
  required_providers { aws = { source = "hashicorp/aws", version = "~> 6.0" } }
}
variable "region" { type = string }
variable "state_bucket" { type = string }
variable "oidc_provider_arn" { type = string }
variable "enable_plan_role" {
  type    = bool
  default = true
}
variable "plan_subject" {
  default = "repo:UNCONFIGURED/UNCONFIGURED:environment:terraform-plan"
  type    = string
  validation {
    condition     = !strcontains(var.plan_subject, "*") && endswith(var.plan_subject, ":environment:terraform-plan")
    error_message = "Use the exact repository subject for terraform-plan."
  }
}
provider "aws" { region = var.region }
resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket
  lifecycle { prevent_destroy = true }
}
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_policy" "tls" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"], Condition = { Bool = { "aws:SecureTransport" = "false" } } }] })
}
resource "aws_iam_role" "plan" {
  count              = var.enable_plan_role ? 1 : 0
  name               = "finzla-development-github-plan"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Federated = var.oidc_provider_arn }, Action = "sts:AssumeRoleWithWebIdentity", Condition = { StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com", "token.actions.githubusercontent.com:sub" = var.plan_subject } } }] })
}
resource "aws_iam_role_policy" "plan" {
  count = var.enable_plan_role ? 1 : 0
  role  = aws_iam_role.plan[0].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["ec2:Describe*", "elasticloadbalancing:Describe*", "ecs:Describe*", "ecs:List*", "ecr:Describe*", "ecr:GetLifecyclePolicy", "ecr:ListTagsForResource", "iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "cloudwatch:DescribeAlarms", "cloudwatch:GetDashboard", "cloudwatch:ListTagsForResource", "logs:DescribeLogGroups", "logs:ListTagsForResource", "sns:GetTopicAttributes", "sns:GetSubscriptionAttributes", "sns:ListTagsForResource"], Resource = "*" },
    { Effect = "Allow", Action = ["s3:ListBucket"], Resource = aws_s3_bucket.state.arn, Condition = { StringLike = { "s3:prefix" = ["development/*"] } } },
    { Effect = "Allow", Action = ["s3:GetObject"], Resource = "${aws_s3_bucket.state.arn}/development/terraform.tfstate" },
    { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], Resource = "${aws_s3_bucket.state.arn}/development/terraform.tfstate.tflock" }
  ] })
}
output "state_bucket" { value = aws_s3_bucket.state.id }
output "plan_role_arn" { value = var.enable_plan_role ? aws_iam_role.plan[0].arn : null }

variable "hostname" {
  type        = string
  default     = null
  description = "Optional public hostname to request an ACM certificate for; DNS validation is handled at the authoritative DNS provider."
}
resource "aws_acm_certificate" "app" {
  count             = var.hostname == null ? 0 : 1
  domain_name       = var.hostname
  validation_method = "DNS"
  tags              = { Project = "finzla", Environment = "development", ManagedBy = "Terraform" }
  lifecycle { create_before_destroy = true }
}
output "certificate_arn" {
  value = var.hostname == null ? null : aws_acm_certificate.app[0].arn
}
output "certificate_validation_records" {
  value = var.hostname == null ? [] : [for record in aws_acm_certificate.app[0].domain_validation_options : {
    name  = record.resource_record_name
    type  = record.resource_record_type
    value = record.resource_record_value
  }]
}
