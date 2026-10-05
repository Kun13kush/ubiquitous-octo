variable "region" { type = string }
variable "environment" {
  type = string
  validation {
    condition     = contains(["development", "production"], var.environment)
    error_message = "Use development or production."
  }
}
variable "vpc_cidr" { type = string }
variable "certificate_arn" { type = string }
variable "hostname" { type = string }
variable "image_uri" {
  type        = string
  description = "Initial ECR image pinned by sha256 digest; seed repository before enabling tasks."
  validation {
    condition     = can(regex("@sha256:[a-f0-9]{64}$", var.image_uri))
    error_message = "Pin the image by SHA256 digest."
  }
}
variable "desired_count" {
  type    = number
  default = 2
  validation {
    condition     = var.desired_count == 0 || var.desired_count >= 2
    error_message = "Zero is bootstrap only; otherwise run at least two tasks."
  }
}
variable "github_oidc_provider_arn" { type = string }
variable "github_deploy_subject" {
  type        = string
  description = "Exact GitHub OIDC sub for this repository and protected environment. Copy the actual subject, including immutable IDs where enabled."
  validation {
    condition     = !strcontains(var.github_deploy_subject, "*") && endswith(var.github_deploy_subject, ":environment:${var.environment}")
    error_message = "Use an exact subject ending in the matching GitHub environment."
  }
}
variable "alert_email" { type = string }
