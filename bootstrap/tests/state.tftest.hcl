mock_provider "aws" {}
variables {
  region            = "eu-west-1"
  state_bucket      = "finzla-assessment-mock-state"
  oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  plan_subject      = "repo:example/finzla:environment:terraform-plan"
}
run "production_bucket_only" {
  command = plan
  variables { enable_plan_role = false }
  assert {
    condition     = length(aws_iam_role.plan) == 0
    error_message = "Production bootstrap must not create a PR plan role."
  }
  assert {
    condition     = aws_s3_bucket_public_access_block.state.block_public_policy && aws_s3_bucket_public_access_block.state.restrict_public_buckets
    error_message = "State must be private."
  }
  assert {
    condition     = aws_s3_bucket_versioning.state.versioning_configuration[0].status == "Enabled"
    error_message = "State must be recoverable."
  }
}
