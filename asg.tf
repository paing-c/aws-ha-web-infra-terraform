resource "aws_autoscaling_group" "web" {
  name                = "${local.name_prefix}-web-asg"
  vpc_zone_identifier = aws_subnet.public[*].id
  min_size            = 2
  desired_capacity    = 2
  max_size            = 3

  # Give user data time to install and start Nginx before acting on ALB health checks.
  health_check_type         = "ELB"
  health_check_grace_period = 120
  target_group_arns         = [aws_lb_target_group.web.arn]

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  # The listener associates the target group with the ALB before instances launch.
  depends_on = [aws_lb_listener.http]

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-web"
    propagate_at_launch = true
  }
}
