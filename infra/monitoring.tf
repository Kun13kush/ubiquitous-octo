resource "aws_sns_topic" "alerts" { name = "${local.name}-alerts" }
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
resource "aws_cloudwatch_metric_alarm" "unhealthy" {
  alarm_name          = "${local.name}-unhealthy-targets"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  dimensions          = { LoadBalancer = aws_lb.app.arn_suffix, TargetGroup = aws_lb_target_group.app.arn_suffix }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}
resource "aws_cloudwatch_metric_alarm" "errors" {
  alarm_name          = "${local.name}-5xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  evaluation_periods  = 2
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  metric_query {
    id          = "rate"
    expression  = "IF(requests >= 100, 100 * (FILL(target_errors, 0) + FILL(alb_errors, 0)) / requests, 0)"
    label       = "5xx percentage with >=100 requests/min"
    return_data = true
  }
  dynamic "metric_query" {
    for_each = { requests = "RequestCount", target_errors = "HTTPCode_Target_5XX_Count", alb_errors = "HTTPCode_ELB_5XX_Count" }
    content {
      id          = metric_query.key
      return_data = false
      metric {
        namespace   = "AWS/ApplicationELB"
        metric_name = metric_query.value
        dimensions  = { LoadBalancer = aws_lb.app.arn_suffix }
        period      = 60
        stat        = "Sum"
      }
    }
  }
}
resource "aws_cloudwatch_dashboard" "app" {
  dashboard_name = local.name
  dashboard_body = jsonencode({ widgets = [
    { type = "metric", x = 0, y = 0, width = 12, height = 6, properties = { title = "Latency p95", region = var.region, period = 60, stat = "p95", metrics = [["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.app.arn_suffix]] } },
    { type = "metric", x = 12, y = 0, width = 12, height = 6, properties = { title = "Unhealthy targets", region = var.region, period = 60, stat = "Maximum", metrics = [["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", aws_lb.app.arn_suffix, "TargetGroup", aws_lb_target_group.app.arn_suffix]] } },
    { type = "metric", x = 0, y = 6, width = 12, height = 6, properties = { title = "Task resource usage", region = var.region, period = 60, stat = "Average", metrics = [["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.app.name, "ServiceName", aws_ecs_service.app.name], ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.app.name, "ServiceName", aws_ecs_service.app.name]] } }
  ] })
}
