output "ecr_repository_url" { value = aws_ecr_repository.app.repository_url }
output "cluster_name" { value = aws_ecs_cluster.app.name }
output "service_name" { value = aws_ecs_service.app.name }
output "deploy_role_arn" { value = aws_iam_role.deploy.arn }
output "alb_dns_name" { value = aws_lb.app.dns_name }
output "base_url" { value = "https://${var.hostname}" }
output "log_group" { value = aws_cloudwatch_log_group.app.name }
output "target_group_arn" { value = aws_lb_target_group.app.arn }
output "initial_task_definition_arn" {
  description = "Terraform-owned template revision; use explicitly during first-service seeding or coordinated template changes."
  value       = aws_ecs_task_definition.app.arn
}
