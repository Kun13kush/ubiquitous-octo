mock_provider "aws" {}
override_data {
  target = data.aws_caller_identity.current
  values = { account_id = "123456789012" }
}
override_data {
  target = data.aws_availability_zones.available
  values = { names = ["eu-west-1a", "eu-west-1b"] }
}
variables {
  region                   = "eu-west-1"
  environment              = "production"
  vpc_cidr                 = "10.30.0.0/16"
  certificate_arn          = "arn:aws:acm:eu-west-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  hostname                 = "api.example.com"
  image_uri                = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/finzla-production@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  github_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  github_deploy_subject    = "repo:example/finzla:environment:production"
  alert_email              = "oncall@example.com"
}
run "secure_platform_plan" {
  command = plan
  assert {
    condition     = aws_ecs_service.app.network_configuration[0].assign_public_ip == false
    error_message = "Tasks must remain private."
  }
  assert {
    condition     = aws_ecs_service.app.desired_count >= 2 && length(aws_subnet.private) == 2
    error_message = "Keep redundant capacity across two AZs."
  }
  assert {
    condition     = aws_lb_listener.https.protocol == "HTTPS" && aws_lb_listener.https.port == 443
    error_message = "Ingress must use HTTPS."
  }
  assert {
    condition     = aws_ecs_service.app.deployment_circuit_breaker[0].rollback
    error_message = "Failed releases must roll back."
  }
  assert {
    condition     = length(aws_route_table.private.route) == 0
    error_message = "Private tasks must have no internet default route."
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.tasks_alb.from_port == 8080 && aws_vpc_security_group_ingress_rule.tasks_alb.cidr_ipv4 == null
    error_message = "Task ingress must come only from the ALB security group."
  }
  assert {
    condition     = jsondecode(aws_ecs_task_definition.app.container_definitions)[0].readonlyRootFilesystem
    error_message = "Use a read-only container filesystem."
  }
}
