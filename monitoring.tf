resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  # Two-minute evaluation needs finer-grained data than EC2 basic monitoring provides.
  period    = 120
  statistic = "Average"
  threshold = 70

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.project_name}-${var.environment}-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0

  dimensions = {
    TargetGroup  = aws_lb_target_group.web.arn_suffix
    LoadBalancer = aws_lb.web.arn_suffix
  }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "Auto Scaling group CPU utilization"
          region = var.aws_region
          view   = "timeSeries"
          period = 300
          stat   = "Average"

          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.web.name]
          ]
          yAxis = {
            left = { label = "CPU (%)", min = 0, max = 100, showUnits = false }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          title  = "Load balancer requests and target health"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          stat   = "Average"

          # Plot request totals on a separate axis so host counts remain readable.
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.web.arn_suffix, { stat = "Sum", yAxis = "right", label = "Requests" }],
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", aws_lb.web.arn_suffix, "TargetGroup", aws_lb_target_group.web.arn_suffix, { label = "Healthy hosts" }],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", aws_lb.web.arn_suffix, "TargetGroup", aws_lb_target_group.web.arn_suffix, { label = "Unhealthy hosts" }]
          ]
          yAxis = {
            left  = { label = "Hosts", min = 0, showUnits = false }
            right = { label = "Requests per minute", min = 0, showUnits = false }
          }
        }
      }
    ]
  })
}
